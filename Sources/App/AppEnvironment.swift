import Foundation
import Observation

/// Dependency container + top-level app state. Injected once at the root via
/// `.environment(...)` and read with `@Environment(AppEnvironment.self)`.
@MainActor
@Observable
public final class AppEnvironment {

    public enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(ProviderError)
    }

    // Dependencies
    public let repository: InMemoryCatalogRepository
    public let searchEngine: SearchEngine
    public let aiService: AIService
    public let watchProgress: WatchProgressStore
    public let favorites: FavoritesStore
    public let providers: ProviderStore
    private let normalizer: Normalizer
    private var provider: (any ProviderClient)?

    // State
    public private(set) var loadState: LoadState = .idle
    public private(set) var vocabulary: SearchVocabulary = .init()

    public var activeProvider: ProviderDescriptor? {
        providers.activeConfiguration?.descriptor
    }

    /// True when there's no provider configured yet — the UI shows onboarding.
    public var needsProviderSetup: Bool { !providers.hasAnyProvider }

    public init() {
        self.repository = InMemoryCatalogRepository()
        self.searchEngine = SearchEngine()
        self.aiService = AIService(mode: .onDeviceOnly)
        self.watchProgress = WatchProgressStore()
        self.favorites = FavoritesStore()
        self.providers = ProviderStore()
        self.normalizer = Normalizer()
    }

    public static func live() -> AppEnvironment { AppEnvironment() }

    /// Fetch + normalise + load the active provider's catalog.
    public func bootstrap(forceReload: Bool = false) async {
        if case .loading = loadState { return }
        if case .ready = loadState, !forceReload { return }

        guard let config = providers.activeConfiguration,
              let client = providers.makeClient(for: config) else {
            loadState = .idle
            return
        }
        provider = client

        loadState = .loading
        do {
            let raw = try await client.fetchRawCatalog()
            let normalizer = self.normalizer
            let catalog = await Task.detached(priority: .userInitiated) {
                normalizer.normalize(raw)
            }.value

            await repository.load(catalog)
            vocabulary = SearchVocabulary.from(catalog: catalog)
            loadState = .ready
            AppLog.app.info("Catalog ready: \(catalog.channels.count) channels, \(catalog.movies.count) movies, \(catalog.series.count) series.")
        } catch {
            let providerError = ProviderError.from(error)
            loadState = .failed(providerError)
            AppLog.provider.error("Bootstrap failed: \(String(describing: providerError))")
        }
    }

    /// Make `config` active and (re)load its catalog.
    public func activate(_ config: ProviderConfiguration) async {
        providers.setActive(config.id)
        loadState = .idle
        await repository.load(Catalog())
        await bootstrap(forceReload: true)
    }

    /// Load episodes for a series that was imported as a shell (Xtream).
    public func ensureEpisodes(forSeries id: CatalogID) async -> Series? {
        guard var series = await repository.series(id: id) else { return nil }
        if series.hasEpisodes { return series }
        guard let key = series.providerSeriesKey, let client = provider,
              let providerID = providers.activeConfiguration?.id else { return series }
        do {
            let rawEpisodes = try await client.fetchEpisodes(seriesKey: key)
            let normalizer = self.normalizer
            let seasons = await Task.detached(priority: .userInitiated) {
                normalizer.seasons(forEpisodes: rawEpisodes, seriesID: id, providerID: providerID)
            }.value
            await repository.attachSeasons(seasons, toSeriesID: id)
            series.seasons = seasons
            return series
        } catch {
            AppLog.provider.error("Episode load failed: \(String(describing: ProviderError.from(error)))")
            return series
        }
    }

    public func setAIMode(_ mode: AIService.Mode) async {
        await aiService.setMode(mode)
    }

    // MARK: - Playback

    /// Build a `PlaybackItem` for a movie, applying any saved resume position.
    public func playback(forMovie id: CatalogID) async -> PlaybackItem? {
        guard let movie = await repository.movie(id: id) else { return nil }
        let resume = watchProgress.progress(for: id)
        return PlaybackItem(
            id: movie.id,
            kind: .movie,
            url: movie.streamURL,
            title: movie.title,
            subtitle: [movie.year.map(String.init), movie.genres.first?.displayName]
                .compactMap { $0 }.joined(separator: " · "),
            isLive: false,
            resumeAt: resume?.isResumable == true ? resume?.positionSeconds : nil,
            durationSeconds: movie.durationMinutes.map { Double($0 * 60) }
        )
    }

    public func playback(forEpisode episode: Episode, seriesTitle: String) -> PlaybackItem {
        let resume = watchProgress.progress(for: episode.id)
        return PlaybackItem(
            id: episode.id,
            kind: .series,
            url: episode.streamURL,
            title: seriesTitle,
            subtitle: "\(episode.code) · \(episode.title)",
            isLive: false,
            resumeAt: resume?.isResumable == true ? resume?.positionSeconds : nil,
            durationSeconds: episode.durationMinutes.map { Double($0 * 60) }
        )
    }

    public func playback(forChannel id: CatalogID) async -> PlaybackItem? {
        guard let channel = await repository.channel(id: id) else { return nil }
        return PlaybackItem(
            id: channel.id,
            kind: .liveChannel,
            url: channel.streamURL,
            title: channel.name,
            subtitle: channel.category,
            isLive: true
        )
    }

    public func recordProgress(id: CatalogID, kind: ContentKind, position: Double, duration: Double) {
        watchProgress.record(id: id, kind: kind, positionSeconds: position, durationSeconds: duration)
    }
}
