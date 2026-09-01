import Foundation
import Observation

@MainActor
@Observable
public final class VODBrowseViewModel {
    public let kind: BrowseKind

    public private(set) var cards: [BrowseCard] = []
    public private(set) var total = 0
    public private(set) var isLoading = false
    public private(set) var canLoadMore = true

    public private(set) var availableGenres: [Genre] = []
    public private(set) var availableAudio: [Language] = []
    public private(set) var availableSubtitles: [Language] = []
    /// A–Z jump targets — populated only when sorting alphabetically.
    public private(set) var anchors: [BrowseAnchor] = []

    public var filter = CatalogFilter()

    private let repository: any CatalogRepository
    private let watchProgress: WatchProgressStore
    private let pageSize = 60
    private var page = 0
    private var reloadTask: Task<Void, Never>?

    public init(kind: BrowseKind, repository: any CatalogRepository, watchProgress: WatchProgressStore) {
        self.kind = kind
        self.repository = repository
        self.watchProgress = watchProgress
    }

    public func start() async {
        async let g = repository.availableGenres()
        async let a = repository.availableAudioLanguages()
        async let s = repository.availableSubtitleLanguages()
        availableGenres = await g
        availableAudio = await a
        availableSubtitles = await s
        await reload()
    }

    public func clearFilters() {
        filter = CatalogFilter(sort: filter.sort)
    }

    /// Debounced — the filter UI calls this on every chip tap; only the settled
    /// filter runs a query.
    public func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await self?.reload()
        }
    }

    public func reload() async {
        isLoading = true
        page = 0
        canLoadMore = true
        // Facets grow while a staged import is still running.
        availableGenres = await repository.availableGenres()
        availableAudio = await repository.availableAudioLanguages()
        availableSubtitles = await repository.availableSubtitleLanguages()
        let snapshotFilter = filter

        switch kind {
        case .movies: total = await repository.moviesCount(filter: snapshotFilter)
        case .series: total = await repository.seriesCount(filter: snapshotFilter)
        }
        guard !Task.isCancelled else { return }

        if snapshotFilter.sort == .titleAscending {
            switch kind {
            case .movies: anchors = await repository.movieTitleAnchors(filter: snapshotFilter)
            case .series: anchors = await repository.seriesTitleAnchors(filter: snapshotFilter)
            }
        } else {
            anchors = []
        }
        guard !Task.isCancelled else { return }

        cards = []
        await loadPage(replacing: true, filter: snapshotFilter)
        isLoading = false
    }

    /// Load pages until the item at `anchor.index` is in `cards`, then return
    /// its id so the view can scroll to it. Pages are O(1) slices of a cached
    /// sorted list, so walking to a deep letter is cheap.
    public func jump(to anchor: BrowseAnchor) async -> CatalogID? {
        let target = filter
        while cards.count <= anchor.index, canLoadMore, filter == target {
            let before = cards.count
            await loadPage(replacing: false, filter: target)
            if cards.count == before { break }
        }
        return cards.indices.contains(anchor.index) ? cards[anchor.index].id : cards.last?.id
    }

    public func loadMoreIfNeeded(currentItem: BrowseCard) async {
        guard canLoadMore, !isLoading,
              let idx = cards.firstIndex(where: { $0.id == currentItem.id }),
              idx >= cards.count - 12
        else { return }
        await loadPage(replacing: false, filter: filter)
    }

    private func loadPage(replacing: Bool, filter: CatalogFilter) async {
        isLoading = true
        defer { isLoading = false }

        let newCards: [BrowseCard]
        switch kind {
        case .movies:
            let movies = await repository.movies(filter: filter, page: page, pageSize: pageSize)
            newCards = movies.map { BrowseCard(movie: $0, progress: progressFraction(for: $0.id)) }
        case .series:
            let series = await repository.series(filter: filter, page: page, pageSize: pageSize)
            newCards = series.map { BrowseCard(series: $0) }
        }
        guard !Task.isCancelled, filter == self.filter else { return }

        if replacing { cards = newCards } else { cards.append(contentsOf: newCards) }
        page += 1
        canLoadMore = newCards.count == pageSize
    }

    private func progressFraction(for id: CatalogID) -> Double? {
        let f = watchProgress.fraction(for: id)
        return f > 0 ? f : nil
    }
}
