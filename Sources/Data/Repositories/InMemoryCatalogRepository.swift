import Foundation

/// M0 repository. Holds a normalised `Catalog` in memory behind an actor and
/// answers queries with plain array operations. Pagination is honoured so
/// callers are already written for the SQLite implementation.
public actor InMemoryCatalogRepository: CatalogRepository {

    private var catalog: Catalog
    private var ready: Bool

    public init(catalog: Catalog = Catalog(), ready: Bool = false) {
        self.catalog = catalog
        self.ready = ready
    }

    public func load(_ catalog: Catalog) {
        self.catalog = catalog
        self.ready = true
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

    public func allChannelCategories() -> [String] {
        let cats = Set(catalog.channels.map(\.category)).sorted()
        return ["All"] + cats
    }

    // MARK: - Movies / Series

    public func movies(filter: CatalogFilter, page: Int, pageSize: Int) -> [Movie] {
        catalog.movies
            .filter { filter.matches(movie: $0) }
            .sorted { Self.order($0.title, $0.year, $1.title, $1.year, filter.sort) }
            .page(page, size: pageSize)
    }

    public func series(filter: CatalogFilter, page: Int, pageSize: Int) -> [Series] {
        catalog.series
            .filter { filter.matches(series: $0) }
            .sorted { Self.order($0.title, $0.year, $1.title, $1.year, filter.sort) }
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

    public func availableGenres() -> [Genre] {
        let set = Set(catalog.movies.flatMap(\.genres) + catalog.series.flatMap(\.genres))
        return Genre.allCases.filter(set.contains)
    }
    public func availableAudioLanguages() -> [Language] {
        Array(Set(catalog.movies.flatMap(\.audioLanguages) + catalog.series.flatMap(\.audioLanguages))).sorted()
    }
    public func availableSubtitleLanguages() -> [Language] {
        Array(Set(catalog.movies.flatMap(\.subtitleLanguages) + catalog.series.flatMap(\.subtitleLanguages))).sorted()
    }

    private static func order(_ lt: String, _ ly: Int?, _ rt: String, _ ry: Int?, _ sort: BrowseSort) -> Bool {
        switch sort {
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

    public func movie(id: CatalogID) -> Movie? { catalog.movies.first { $0.id == id } }
    public func series(id: CatalogID) -> Series? { catalog.series.first { $0.id == id } }
    public func channel(id: CatalogID) -> Channel? { catalog.channels.first { $0.id == id } }

    public func attachSeasons(_ seasons: [Season], toSeriesID id: CatalogID) {
        guard let idx = catalog.series.firstIndex(where: { $0.id == id }) else { return }
        catalog.series[idx].seasons = seasons
    }

    public func recentlyAdded(limit: Int) -> [SearchResult.Item] {
        let movies = catalog.movies.suffix(limit).reversed().map { SearchResult.Item.movie($0) }
        let series = catalog.series.suffix(limit).reversed().map { SearchResult.Item.series($0) }
        return Array((movies + series).prefix(limit))
    }

    // MARK: - EPG

    public func epgEvents(forEPGID epgID: String, in window: DateInterval) -> [EPGEvent] {
        catalog.events(forEPGID: epgID, in: window)
    }

    public func nowPlaying(forEPGID epgID: String, at date: Date) -> EPGEvent? {
        catalog.nowPlaying(forEPGID: epgID, at: date)
    }

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
