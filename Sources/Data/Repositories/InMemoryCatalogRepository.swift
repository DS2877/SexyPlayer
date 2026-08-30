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

    public func setHideAdult(_ hide: Bool) {
        guard hide != hideAdult else { return }
        hideAdult = hide
        rebuildVisible()
    }

    private func rebuildVisible() {
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

    public func channels(in category: String?, page: Int, pageSize: Int) -> [Channel] {
        var list = catalog.channels
        if let category, category != "All" {
            list = list.filter { $0.category == category }
        }
        list.sort { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
        return list.page(page, size: pageSize)
    }

    public func allChannelCategories() -> [String] { facetCategories }

    // MARK: - Movies / Series

    public func movies(filter: CatalogFilter, page: Int, pageSize: Int) -> [Movie] {
        catalog.movies
            .filter { filter.matches(movie: $0) }
            .sorted { Self.order($0.title, $0.year, $0.addedAt, $1.title, $1.year, $1.addedAt, filter.sort) }
            .page(page, size: pageSize)
    }

    public func series(filter: CatalogFilter, page: Int, pageSize: Int) -> [Series] {
        catalog.series
            .filter { filter.matches(series: $0) }
            .sorted { Self.order($0.title, $0.year, $0.addedAt, $1.title, $1.year, $1.addedAt, filter.sort) }
            .page(page, size: pageSize)
    }

    public func moviesCount(filter: CatalogFilter) -> Int {
        catalog.movies.reduce(0) { filter.matches(movie: $1) ? $0 + 1 : $0 }
    }
    public func seriesCount(filter: CatalogFilter) -> Int {
        catalog.series.reduce(0) { filter.matches(series: $1) ? $0 + 1 : $0 }
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
