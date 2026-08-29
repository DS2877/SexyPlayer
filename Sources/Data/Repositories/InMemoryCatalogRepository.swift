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
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
            .page(page, size: pageSize)
    }

    public func series(filter: CatalogFilter, page: Int, pageSize: Int) -> [Series] {
        catalog.series
            .filter { filter.matches(series: $0) }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
            .page(page, size: pageSize)
    }

    public func movie(id: CatalogID) -> Movie? { catalog.movies.first { $0.id == id } }
    public func series(id: CatalogID) -> Series? { catalog.series.first { $0.id == id } }
    public func channel(id: CatalogID) -> Channel? { catalog.channels.first { $0.id == id } }

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
