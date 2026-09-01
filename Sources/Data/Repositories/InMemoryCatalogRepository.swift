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
    /// When on, foreign-region channels / movies / series are hidden everywhere
    /// (see `RelevanceFilter`). The app switches this on from `UserPreferences`
    /// via `applyPreferences()`; off here so tests see the raw catalog.
    private var regionLimited = false

    // Indexes rebuilt whenever `catalog` changes — keep large-library queries
    // off the O(n) path. The id→item maps store *array indices*, not struct
    // copies: a `[CatalogID: Movie]` for a 50k-title library duplicates ~20 MB
    // of value types for nothing.
    private var epgByChannel: [String: [EPGEvent]] = [:]   // each list sorted by start
    private var movieIndexByID: [CatalogID: Int] = [:]
    private var seriesIndexByID: [CatalogID: Int] = [:]
    private var channelIndexByID: [CatalogID: Int] = [:]
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

    public func setRegionLimit(_ limited: Bool) {
        guard limited != regionLimited else { return }
        regionLimited = limited
        rebuildVisible()
    }

    private func rebuildVisible() {
        movieQueryCache = nil
        seriesQueryCache = nil
        channelQueryCache = nil

        let keepChannel: (Channel) -> Bool = { [hideAdult, regionLimited] c in
            if hideAdult && c.isAdult { return false }
            if regionLimited && !RelevanceFilter.isRelevant(countryCode: c.countryCode,
                                                            name: c.name, category: c.category) { return false }
            return true
        }
        let keepMovie: (Movie) -> Bool = { [hideAdult, regionLimited] m in
            if hideAdult && m.isAdult { return false }
            if regionLimited && !RelevanceFilter.isRelevant(countryCode: m.countryCode,
                                                            name: m.title, category: m.genres.first?.displayName ?? "") { return false }
            return true
        }
        let keepSeries: (Series) -> Bool = { [hideAdult, regionLimited] s in
            if hideAdult && s.isAdult { return false }
            if regionLimited && !RelevanceFilter.isRelevant(countryCode: s.countryCode,
                                                            name: s.title, category: s.genres.first?.displayName ?? "") { return false }
            return true
        }

        if hideAdult || regionLimited {
            catalog = Catalog(
                channels: source.channels.filter(keepChannel),
                movies: source.movies.filter(keepMovie),
                series: source.series.filter(keepSeries),
                epg: source.epg
            )
        } else {
            catalog = source
        }
        rebuildIndexes()
    }

    private func rebuildIndexes() {
        movieIndexByID = Dictionary(catalog.movies.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        seriesIndexByID = Dictionary(catalog.series.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        channelIndexByID = Dictionary(catalog.channels.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })

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
    /// The viewer's home country codes (from chosen languages) — channels from
    /// these sort first in `.number` mode. Set via `applyPreferences()`.
    private var homeRegions: Set<String> = ["SE"]
    /// Recently-watched channel ids → recency rank (0 = most recent). These float
    /// to the very top of `.number` mode.
    private var recentChannelRank: [CatalogID: Int] = [:]

    public func setHomeRegions(_ regions: Set<String>) {
        guard regions != homeRegions else { return }
        homeRegions = regions
        channelQueryCache = nil
    }

    public func setRecentChannels(_ ids: [CatalogID]) {
        let rank = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        guard rank != recentChannelRank else { return }
        recentChannelRank = rank
        channelQueryCache = nil
    }

    private func sortedChannels(in rawCategory: String?, sort: ChannelSort) -> [Channel] {
        let category = (rawCategory == "All") ? nil : rawCategory   // same result either way
        if let c = channelQueryCache, c.category == category, c.sort == sort { return c.result }
        var list = catalog.channels
        if let category {
            list = list.filter { $0.category == category }
        }
        switch sort {
        case .number:
            let home = homeRegions
            let recent = recentChannelRank
            list.sort { lhs, rhs in
                // 1. channels the viewer actually watches, most recent first
                let lr = recent[lhs.id], rr = recent[rhs.id]
                if (lr != nil) != (rr != nil) { return lr != nil }
                if let lr, let rr, lr != rr { return lr < rr }
                // 2. home country, then other Nordic, then English, then the rest
                let lp = RelevanceFilter.priority(countryCode: lhs.countryCode, home: home)
                let rp = RelevanceFilter.priority(countryCode: rhs.countryCode, home: home)
                if lp != rp { return lp < rp }
                // 3. the provider's channel number, then name
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

    public func movie(id: CatalogID) -> Movie? { movieIndexByID[id].map { catalog.movies[$0] } }
    public func series(id: CatalogID) -> Series? { seriesIndexByID[id].map { catalog.series[$0] } }
    public func channel(id: CatalogID) -> Channel? { channelIndexByID[id].map { catalog.channels[$0] } }

    public func attachSeasons(_ seasons: [Season], toSeriesID id: CatalogID) {
        if let i = source.series.firstIndex(where: { $0.id == id }) { source.series[i].seasons = seasons }
        // `series(id:)` reads `catalog.series[idx]` live, so mutating it here is
        // enough — no cached struct to refresh.
        if let j = seriesIndexByID[id] { catalog.series[j].seasons = seasons }
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
