import Foundation

/// M0 repository. Holds a normalised `Catalog` in memory behind an actor and
/// answers queries with plain array operations. Pagination is honoured so
/// callers are already written for the SQLite implementation.
public actor InMemoryCatalogRepository: CatalogRepository {

    /// Full imported catalog.
    private var source: Catalog
    /// `source` with adult items removed when `hideAdult` is on — every query
    /// reads this.
    private var catalog: Catalog
    private var ready: Bool
    private var hideAdult = false

    // Indexes rebuilt whenever `catalog` changes — keep large-library queries
    // off the O(n) path.
    private var epgByChannel: [String: [EPGEvent]] = [:]   // each list sorted by start
    private var movieByID: [CatalogID: Movie] = [:]
    private var seriesByID: [CatalogID: Series] = [:]
    private var channelByID: [CatalogID: Channel] = [:]
    private var facetGenres: [Genre] = []
    private var facetAudio: [Language] = []
    private var facetSubtitles: [Language] = []
    private var facetCategories: [String] = ["All"]

    public init(catalog: Catalog = Catalog(), ready: Bool = false) {
        self.source = catalog
        self.catalog = catalog
        self.ready = ready
        rebuildVisible()
    }

    public func load(_ catalog: Catalog) {
        self.source = catalog
        self.ready = true
        rebuildVisible()
    }

    /// Phase 1 of a cached start: channels only → the app is interactive.
    public func loadChannelsOnly(_ channels: [Channel]) {
        self.source = Catalog(channels: channels)
        self.ready = true
        rebuildVisible()
    }

    /// Phase 2: movies + series stream in from the cache.
    public func mergeVOD(movies: [Movie], series: [Series]) {
        source.movies = movies
        source.series = series
        rebuildVisible()
    }

    /// Phase 3: EPG. Only re-indexes the guide, not the whole catalog.
    public func mergeEPG(_ events: [EPGEvent]) {
        source.epg = events
        catalog.epg = events
        var index: [String: [EPGEvent]] = [:]
        for event in events { index[event.channelEPGID, default: []].append(event) }
        for key in index.keys { index[key]?.sort { $0.start < $1.start } }
        epgByChannel = index
    }

    public func setHideAdult(_ hide: Bool) {
        guard hide != hideAdult else { return }
        hideAdult = hide
        rebuildVisible()
    }

    private func rebuildVisible() {
        movieQueryCache = nil
        seriesQueryCache = nil
        channelQueryCache = nil
        if hideAdult {
            catalog = Catalog(
                channels: source.channels.filter { !$0.isAdult },
                movies: source.movies.filter { !$0.isAdult },
                series: source.series.filter { !$0.isAdult },
                epg: source.epg
            )
        } else {
            catalog = source
        }
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        movieByID = Dictionary(catalog.movies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        seriesByID = Dictionary(catalog.series.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        channelByID = Dictionary(catalog.channels.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var epg: [String: [EPGEvent]] = [:]
        for event in catalog.epg { epg[event.channelEPGID, default: []].append(event) }
        for key in epg.keys { epg[key]?.sort { $0.start < $1.start } }
        epgByChannel = epg

        let genres = Set(catalog.movies.flatMap(\.genres)) .union(catalog.series.flatMap(\.genres))
        facetGenres = Genre.allCases.filter(genres.contains)
        facetAudio = Array(Set(catalog.movies.flatMap(\.audioLanguages)).union(catalog.series.flatMap(\.audioLanguages))).sorted()
        facetSubtitles = Array(Set(catalog.movies.flatMap(\.subtitleLanguages)).union(catalog.series.flatMap(\.subtitleLanguages))).sorted()
        facetCategories = ["All"] + Set(catalog.channels.map(\.category)).sorted()
    }

    public func isReady() -> Bool { ready }

    // MARK: - Channels

    private var channelQueryCache: (category: String?, sort: ChannelSort, result: [Channel])?

    private func sortedChannels(in category: String?, sort: ChannelSort) -> [Channel] {
        if let c = channelQueryCache, c.category == category, c.sort == sort { return c.result }
        var list = catalog.channels
        if let category, category != "All" {
            list = list.filter { $0.category == category }
        }
        switch sort {
        case .number:
            list.sort { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
        case .nameAsc:
            list.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
        channelQueryCache = (category, sort, list)
        return list
    }

    public func channels(in category: String?, sort: ChannelSort, page: Int, pageSize: Int) -> [Channel] {
        sortedChannels(in: category, sort: sort).page(page, size: pageSize)
    }

    public func channelTitleAnchors(in category: String?) -> [BrowseAnchor] {
        Self.anchors(sortedChannels(in: category, sort: .nameAsc).map(\.name))
    }

    public func allChannelCategories() -> [String] { facetCategories }

    // MARK: - Movies / Series

    // A one-deep cache of the last sorted+filtered result. Browse paginates by
    // calling back for page after page of the *same* filter; without this each
    // page re-sorts the whole library (O(n log n) × pages).
    private var movieQueryCache: (filter: CatalogFilter, result: [Movie])?
    private var seriesQueryCache: (filter: CatalogFilter, result: [Series])?

    private func sortedFilteredMovies(_ filter: CatalogFilter) -> [Movie] {
        if let c = movieQueryCache, c.filter == filter { return c.result }
        let result = catalog.movies
            .filter { filter.matches(movie: $0) }
            .sorted { Self.order($0.title, $0.year, $0.addedAt, $1.title, $1.year, $1.addedAt, filter.sort) }
        movieQueryCache = (filter, result)
        return result
    }

    private func sortedFilteredSeries(_ filter: CatalogFilter) -> [Series] {
        if let c = seriesQueryCache, c.filter == filter { return c.result }
        let result = catalog.series
            .filter { filter.matches(series: $0) }
            .sorted { Self.order($0.title, $0.year, $0.addedAt, $1.title, $1.year, $1.addedAt, filter.sort) }
        seriesQueryCache = (filter, result)
        return result
    }

    public func movies(filter: CatalogFilter, page: Int, pageSize: Int) -> [Movie] {
        sortedFilteredMovies(filter).page(page, size: pageSize)
    }

    public func series(filter: CatalogFilter, page: Int, pageSize: Int) -> [Series] {
        sortedFilteredSeries(filter).page(page, size: pageSize)
    }

    public func moviesCount(filter: CatalogFilter) -> Int {
        sortedFilteredMovies(filter).count
    }
    public func seriesCount(filter: CatalogFilter) -> Int {
        sortedFilteredSeries(filter).count
    }

    /// First-letter jump targets for an A–Z browse list: the index in the
    /// sorted+filtered result where each initial letter starts.
    public func movieTitleAnchors(filter: CatalogFilter) -> [BrowseAnchor] {
        Self.anchors(sortedFilteredMovies(filter).map(\.title))
    }
    public func seriesTitleAnchors(filter: CatalogFilter) -> [BrowseAnchor] {
        Self.anchors(sortedFilteredSeries(filter).map(\.title))
    }

    private static func anchors(_ titles: [String]) -> [BrowseAnchor] {
        var result: [BrowseAnchor] = []
        var seen = Set<String>()
        for (index, title) in titles.enumerated() {
            let letter = anchorLetter(for: title)
            if seen.insert(letter).inserted {
                result.append(BrowseAnchor(letter: letter, index: index))
            }
        }
        return result
    }

    private static func anchorLetter(for title: String) -> String {
        let stripped = title.folding(options: .diacriticInsensitive, locale: nil)
            .drop { !$0.isLetter && !$0.isNumber }
        guard let first = stripped.first else { return "#" }
        return first.isNumber ? "#" : first.uppercased()
    }
    public func channelsCount(in category: String?) -> Int {
        guard let category, category != "All" else { return catalog.channels.count }
        return catalog.channels.reduce(0) { $1.category == category ? $0 + 1 : $0 }
    }

    public func availableGenres() -> [Genre] { facetGenres }
    public func availableAudioLanguages() -> [Language] { facetAudio }
    public func availableSubtitleLanguages() -> [Language] { facetSubtitles }

    private static func order(_ lt: String, _ ly: Int?, _ la: Date?,
                              _ rt: String, _ ry: Int?, _ ra: Date?,
                              _ sort: BrowseSort) -> Bool {
        switch sort {
        case .recentlyAdded:
            let l = la ?? .distantPast, r = ra ?? .distantPast
            if l != r { return l > r }
            return lt.localizedCompare(rt) == .orderedAscending
        case .titleAscending:
            return lt.localizedCompare(rt) == .orderedAscending
        case .newest:
            if (ly ?? 0) != (ry ?? 0) { return (ly ?? 0) > (ry ?? 0) }
            return lt.localizedCompare(rt) == .orderedAscending
        case .oldest:
            if (ly ?? Int.max) != (ry ?? Int.max) { return (ly ?? Int.max) < (ry ?? Int.max) }
            return lt.localizedCompare(rt) == .orderedAscending
        }
    }

    public func movie(id: CatalogID) -> Movie? { movieByID[id] }
    public func series(id: CatalogID) -> Series? { seriesByID[id] }
    public func channel(id: CatalogID) -> Channel? { channelByID[id] }

    public func attachSeasons(_ seasons: [Season], toSeriesID id: CatalogID) {
        if let i = source.series.firstIndex(where: { $0.id == id }) { source.series[i].seasons = seasons }
        if let j = catalog.series.firstIndex(where: { $0.id == id }) {
            catalog.series[j].seasons = seasons
            seriesByID[id] = catalog.series[j]
        }
        seriesQueryCache = nil
    }

    public func recentlyAdded(limit: Int) -> [SearchResult.Item] {
        let movies = catalog.movies.suffix(limit).reversed().map { SearchResult.Item.movie($0) }
        let series = catalog.series.suffix(limit).reversed().map { SearchResult.Item.series($0) }
        return Array((movies + series).prefix(limit))
    }

    // MARK: - EPG (indexed — each channel's events are pre-sorted by start)

    public func epgEvents(forEPGID epgID: String, in window: DateInterval) -> [EPGEvent] {
        epgByChannel.events(forChannel: epgID, in: window)
    }

    public func nowPlaying(forEPGID epgID: String, at date: Date) -> EPGEvent? {
        epgByChannel.nowPlaying(forChannel: epgID, at: date)
    }

    public func epgIndex() -> [String: [EPGEvent]] { epgByChannel }

    public func snapshot() -> Catalog { catalog }

    /// The full, unfiltered catalog — for persisting to the on-disk cache after
    /// a staged import.
    public func exportCatalog() -> Catalog { source }

    // MARK: - "More Like This"

    public func similarMovies(to id: CatalogID, genres: [Genre], limit: Int) -> [Movie] {
        guard !genres.isEmpty else { return [] }
        let want = Set(genres)
        return catalog.movies
            .filter { $0.id != id && !want.isDisjoint(with: $0.genres) }
            .sorted { lhs, rhs in
                let l = want.intersection(lhs.genres).count
                let r = want.intersection(rhs.genres).count
                if l != r { return l > r }
                return (lhs.addedAt ?? .distantPast) > (rhs.addedAt ?? .distantPast)
            }
            .prefix(limit).map { $0 }
    }

    public func similarSeries(to id: CatalogID, genres: [Genre], limit: Int) -> [Series] {
        guard !genres.isEmpty else { return [] }
        let want = Set(genres)
        return catalog.series
            .filter { $0.id != id && !want.isDisjoint(with: $0.genres) }
            .sorted { lhs, rhs in
                let l = want.intersection(lhs.genres).count
                let r = want.intersection(rhs.genres).count
                if l != r { return l > r }
                return (lhs.addedAt ?? .distantPast) > (rhs.addedAt ?? .distantPast)
            }
            .prefix(limit).map { $0 }
    }

    /// Seeds for the background TMDB enrichment sweep — most recently added
    /// first, since that's what the user browses before anything else.
    public func artworkSeeds(movieLimit: Int, seriesLimit: Int) -> [ArtworkSeed] {
        let movies = catalog.movies
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .prefix(movieLimit)
            .map { ArtworkSeed(id: $0.id, title: $0.title, year: $0.year, isSeries: false) }
        let series = catalog.series
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .prefix(seriesLimit)
            .map { ArtworkSeed(id: $0.id, title: $0.title, year: $0.year, isSeries: true) }
        return Array(movies) + Array(series)
    }
}

// MARK: - Filtering

extension CatalogFilter {
    func matches(movie m: Movie) -> Bool {
        matchesCommon(
            genres: m.genres, audio: m.audioLanguages, subs: m.subtitleLanguages,
            year: m.year, quality: m.quality, duration: m.durationMinutes, title: m.title
        )
    }

    func matches(series s: Series) -> Bool {
        matchesCommon(
            genres: s.genres, audio: s.audioLanguages, subs: s.subtitleLanguages,
            year: s.year, quality: s.quality, duration: nil, title: s.title
        )
    }

    private func matchesCommon(
        genres itemGenres: [Genre],
        audio: [Language],
        subs: [Language],
        year: Int?,
        quality: VideoQuality,
        duration: Int?,
        title: String
    ) -> Bool {
        if !genres.isEmpty, Set(genres).isDisjoint(with: Set(itemGenres)) { return false }
        if !audioLanguages.isEmpty, Set(audioLanguages).isDisjoint(with: Set(audio)) { return false }
        if !subtitleLanguages.isEmpty, Set(subtitleLanguages).isDisjoint(with: Set(subs)) { return false }
        if let minYear { guard let y = year, y >= minYear else { return false } }
        if let maxYear { guard let y = year, y <= maxYear else { return false } }
        if let minQuality, quality < minQuality { return false }
        if let maxDurationMinutes {
            if let d = duration, d > maxDurationMinutes { return false }
        }
        if !text.isEmpty {
            let needle = text.foldedForSearch()
            if !needle.isEmpty, !title.foldedForSearch().contains(needle) { return false }
        }
        return true
    }
}

// MARK: - Pagination

extension Array {
    func page(_ page: Int, size: Int) -> [Element] {
        guard size > 0, page >= 0 else { return [] }
        let start = page * size
        guard start < count else { return [] }
        return Array(self[start..<Swift.min(start + size, count)])
    }
}
