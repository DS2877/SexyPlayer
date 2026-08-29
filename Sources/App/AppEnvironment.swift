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
    public let preferences: PreferencesStore
    private let normalizer: Normalizer
    private let cache = CatalogCache()
    private var provider: (any ProviderClient)?
    private var refreshTask: Task<Void, Never>?

    /// How old a cached catalog can be before we silently refresh it on launch.
    private let staleAfter: TimeInterval = 60 * 60 * 6

    /// True while a background library refresh is running (cache was shown first).
    public private(set) var isRefreshing = false

    // State
    public private(set) var loadState: LoadState = .idle
    public private(set) var vocabulary: SearchVocabulary = .init()
    /// Phases the current/most-recent import has reached — drives the
    /// "Preparing your library" checklist.
    public private(set) var reachedPhases: Set<ImportPhase> = []
    /// True once a catalog has loaded at least once this session.
    public private(set) var hasLoadedOnce = false

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
        self.preferences = PreferencesStore()
        self.normalizer = Normalizer()
    }

    /// Push the current content preferences into the repository. Call after a
    /// load and whenever preferences change.
    public func applyPreferences() async {
        await repository.setHideAdult(preferences.preferences.hideAdultContent)
    }

    public static func live() -> AppEnvironment { AppEnvironment() }

    /// Load the active provider's catalog: cached copy first (instant), then a
    /// background refresh from the provider. A full foreground import (with the
    /// progress checklist) only happens when there's no usable cache.
    public func bootstrap(forceReload: Bool = false) async {
        if case .loading = loadState { return }
        if case .ready = loadState, !forceReload { return }

        guard let config = providers.activeConfiguration,
              let client = providers.makeClient(for: config) else {
            loadState = .idle
            return
        }
        provider = client
        let providerID = config.id

        // Fast path: a cached catalog.
        if !forceReload, let entry = await cache.load(providerID: providerID), !entry.catalog.isEmpty {
            await repository.load(entry.catalog)
            await applyPreferences()
            vocabulary = SearchVocabulary.from(catalog: entry.catalog)
            loadState = .ready
            hasLoadedOnce = true
            AppLog.app.info("Loaded catalog from cache (\(Int(entry.age))s old).")
            if entry.age > staleAfter {
                startBackgroundRefresh(client: client, providerID: providerID)
            }
            return
        }

        // Slow path: full import with the progress checklist.
        reachedPhases = []
        loadState = .loading
        let reporter = ImportProgressReporter { [weak self] phase in
            Task { @MainActor in self?.markPhase(phase) }
        }
        do {
            let catalog = try await importCatalog(client: client, reporter: reporter)
            markPhase(.finalizing)                       // normalize done; now indexing
            await repository.load(catalog)
            await applyPreferences()
            vocabulary = SearchVocabulary.from(catalog: catalog)
            loadState = .ready                           // app is usable now
            hasLoadedOnce = true
            AppLog.app.info("Catalog ready: \(catalog.channels.count) channels, \(catalog.movies.count) movies, \(catalog.series.count) series.")
            // Persist in the background — a large catalog can take seconds to encode.
            let toCache = catalog
            Task.detached(priority: .utility) { [cache] in
                await cache.save(toCache, providerID: providerID)
            }
        } catch {
            let providerError = ProviderError.from(error)
            loadState = .failed(providerError)
            AppLog.provider.error("Bootstrap failed: \(String(describing: providerError))")
        }
    }

    /// Manually re-pull the active provider's library (Settings → Refresh).
    public func refreshLibrary() async {
        guard let client = provider, let providerID = providers.activeConfiguration?.id else { return }
        startBackgroundRefresh(client: client, providerID: providerID)
        await refreshTask?.value
    }

    private func importCatalog(client: any ProviderClient, reporter: ImportProgressReporter) async throws -> Catalog {
        let raw = try await client.fetchRawCatalog(progress: reporter)
        let normalizer = self.normalizer
        return await Task.detached(priority: .userInitiated) { normalizer.normalize(raw) }.value
    }

    private func startBackgroundRefresh(client: any ProviderClient, providerID: String) {
        guard refreshTask == nil else { return }
        isRefreshing = true
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.refreshTask = nil; self.isRefreshing = false }
            do {
                let catalog = try await self.importCatalog(client: client, reporter: .ignore)
                // Provider may have changed while we were fetching.
                guard !Task.isCancelled,
                      self.providers.activeConfiguration?.id == providerID else { return }
                await self.repository.load(catalog)
                await self.applyPreferences()
                self.vocabulary = SearchVocabulary.from(catalog: catalog)
                await self.cache.save(catalog, providerID: providerID)
                AppLog.app.info("Catalog refreshed in background.")
            } catch {
                AppLog.provider.notice("Background refresh failed; keeping cached catalog.")
            }
        }
    }

    private func markPhase(_ phase: ImportPhase) {
        let order = ImportPhase.allCases
        guard let idx = order.firstIndex(of: phase) else { return }
        reachedPhases.formUnion(order.prefix(idx + 1))
    }

    /// Make `config` active and load its catalog (cache first, else full import).
    public func activate(_ config: ProviderConfiguration) async {
        refreshTask?.cancel()
        refreshTask = nil
        providers.setActive(config.id)
        loadState = .idle
        hasLoadedOnce = false
        reachedPhases = []
        await repository.load(Catalog())
        await bootstrap(forceReload: false)
    }

    /// Remove a provider and its cached catalog.
    public func removeProvider(_ id: String) async {
        providers.remove(id)
        await cache.clear(providerID: id)
        if !providers.hasAnyProvider {
            await repository.load(Catalog())
            loadState = .idle
            hasLoadedOnce = false
        }
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
