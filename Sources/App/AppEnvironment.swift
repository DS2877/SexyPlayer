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
    public let parental: ParentalControlsStore
    public let metadata = MetadataService()
    private let normalizer: Normalizer
    private let cache = CatalogCache()
    private var provider: (any ProviderClient)?
    private var refreshTask: Task<Void, Never>?
    private var backgroundLoadTask: Task<Void, Never>?

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
    /// False while the EPG (and, on a cold start, the full VOD set) is still
    /// loading in the background after the app became interactive.
    public private(set) var catalogComplete = false
    /// Bumps every time the background load finishes — views observe it to refresh.
    public private(set) var catalogRevision = 0
    /// Bumps as the background TMDB sweep lands batches of ratings/artwork.
    /// Only Home observes this (for the "Top Rated" row).
    public private(set) var metadataRevision = 0

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
        self.parental = ParentalControlsStore()
        self.normalizer = Normalizer()
    }

    /// Keychain accounts for the optional API keys.
    static let aiKeyAccount = "anthropic.apiKey.v1"
    static let tmdbKeyAccount = "tmdb.apiKey.v1"

    /// Push the current preferences into the parts of the app that need them.
    /// Call after a load and whenever preferences change.
    public func applyPreferences() async {
        let prefs = preferences.preferences
        await repository.setHideAdult(prefs.hideAdultContent)
        await aiService.setMode(prefs.aiAssistedSearch ? .assisted : .onDeviceOnly)

        let aiKey = KeychainStore.get(Self.aiKeyAccount) ?? ""
        await aiService.setRemoteParser(aiKey.isEmpty ? nil : ClaudeQueryParser(apiKey: aiKey))
        await metadata.setKey(effectiveTMDBKey)
    }

    /// A key entered in Settings wins; otherwise the bundled default.
    private var effectiveTMDBKey: String {
        let custom = (KeychainStore.get(Self.tmdbKeyAccount) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? TMDBDefaults.readAccessToken : custom
    }

    public func setTMDBKey(_ key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { KeychainStore.delete(Self.tmdbKeyAccount) }
        else { KeychainStore.set(trimmed, for: Self.tmdbKeyAccount) }
        await metadata.setKey(effectiveTMDBKey)
    }

    /// True when a *custom* key is set (the default always works regardless).
    public var hasTMDBKey: Bool {
        !(KeychainStore.get(Self.tmdbKeyAccount) ?? "").isEmpty
    }

    /// Store or clear the AI-assisted-search API key, then re-wire the parser.
    public func setAIKey(_ key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.delete(Self.aiKeyAccount)
        } else {
            KeychainStore.set(trimmed, for: Self.aiKeyAccount)
        }
        await applyPreferences()
    }

    public var hasAIKey: Bool {
        !(KeychainStore.get(Self.aiKeyAccount) ?? "").isEmpty
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

        // Fast path: cached catalog, loaded in phases. Channels first → the app
        // is interactive in well under a second; movies/series and then the EPG
        // stream in behind it.
        if !forceReload, let chans = await cache.loadChannels(providerID: providerID), !chans.channels.isEmpty {
            catalogComplete = false
            backgroundLoadTask?.cancel()
            await repository.loadChannelsOnly(chans.channels)
            await applyPreferences()
            loadState = .ready
            hasLoadedOnce = true
            AppLog.app.info("Cache channels loaded (\(Int(chans.age))s old) — \(chans.channels.count) channels.")

            backgroundLoadTask = Task { [weak self] in
                guard let self else { return }
                let vod = await self.cache.loadVOD(providerID: providerID)
                guard !Task.isCancelled else { return }
                await self.repository.mergeVOD(movies: vod.movies, series: vod.series)
                self.vocabulary = await Task.detached {
                    SearchVocabulary.from(catalog: Catalog(movies: vod.movies, series: vod.series))
                }.value
                self.catalogRevision += 1

                let events = await self.cache.loadEPG(providerID: providerID)
                guard !Task.isCancelled else { return }
                await self.repository.mergeEPG(events)
                self.catalogComplete = true
                self.catalogRevision += 1
                AppLog.app.info("Cache fully loaded — \(vod.movies.count) mv · \(vod.series.count) sr · \(events.count) EPG.")
                self.startMetadataWarmUp()
            }

            if chans.age > staleAfter {
                startBackgroundRefresh(client: client, providerID: providerID)
            }
            return
        }

        // Slow path: staged cold import. The app becomes interactive the moment
        // the channels land; movies/series and then the EPG stream in behind it,
        // exactly like the cached fast path above.
        reachedPhases = []
        catalogComplete = false
        loadState = .loading
        let reporter = ImportProgressReporter { [weak self] phase in
            Task { @MainActor in self?.markPhase(phase) }
        }
        do {
            let importStart = Date()

            try await client.fetchStaged(progress: reporter) { [weak self] stage in
                guard let self else { return }
                await self.ingest(stage, providerID: providerID)
            }
            guard providers.activeConfiguration?.id == providerID else { return }

            let assembled = await repository.exportCatalog()
            guard !assembled.isEmpty else {
                loadState = .failed(.emptyLibrary)
                AppLog.provider.error("Staged import produced an empty catalog.")
                return
            }

            // A VOD-only provider never fires a channels stage — go ready now.
            if loadState != .ready {
                await applyPreferences()
                loadState = .ready
                hasLoadedOnce = true
            }
            markPhase(.finalizing)
            catalogComplete = true
            catalogRevision += 1
            vocabulary = await Task.detached { SearchVocabulary.from(catalog: assembled) }.value

            let elapsed = String(format: "%.1f", Date().timeIntervalSince(importStart))
            AppLog.app.info("Catalog ready (staged) in \(elapsed)s — \(RuntimeStats.catalogSummary(assembled)).")
            await cache.save(assembled, providerID: providerID)
            startMetadataWarmUp()
        } catch {
            if loadState == .ready {
                // The user already has a working app — keep the partial catalog
                // rather than throwing them back to an error screen.
                catalogComplete = true
                AppLog.provider.notice("Import stage failed after going interactive; keeping partial catalog.")
            } else {
                let providerError = ProviderError.from(error)
                loadState = .failed(providerError)
                AppLog.provider.error("Bootstrap failed: \(String(describing: providerError))")
            }
        }
    }

    /// Fold one staged fetch slice into the live repository. `@MainActor` (class
    /// default) so it can update published state directly.
    private func ingest(_ stage: RawStage, providerID: String) async {
        // The user may have switched providers while this import was in flight.
        guard providers.activeConfiguration?.id == providerID else { return }
        switch stage {
        case .channels(let raw):
            let channels = await normalizer.normalizeChannels(raw, providerID: providerID)
            await repository.loadChannelsOnly(channels)
            await applyPreferences()
            loadState = .ready
            hasLoadedOnce = true
        case .vod(let movies, let shells, let episodes):
            let result = await normalizer.normalizeVOD(
                movies: movies, shells: shells, episodes: episodes, providerID: providerID
            )
            await repository.mergeVOD(movies: result.movies, series: result.series)
            catalogRevision += 1
        case .guide(let raw):
            let now = Date()
            let lower = now.addingTimeInterval(-Self.epgWindowPast)
            let upper = now.addingTimeInterval(Self.epgWindowFuture)
            let windowed = raw.filter { $0.stop > lower && $0.start < upper }
            let events = await normalizer.normalizeGuide(windowed)
            await repository.mergeEPG(events)
            catalogRevision += 1
        }
    }

    /// Manually re-pull the active provider's library (Settings → Refresh).
    public func refreshLibrary() async {
        guard let client = provider, let providerID = providers.activeConfiguration?.id else { return }
        startBackgroundRefresh(client: client, providerID: providerID)
        await refreshTask?.value
    }

    /// EPG kept in memory: enough for "now", tonight, and a week-ahead guide.
    /// A real provider's full XMLTV can be millions of events — never hold it all.
    private static let epgWindowPast: TimeInterval = 6 * 3600
    private static let epgWindowFuture: TimeInterval = 14 * 24 * 3600

    private func importCatalog(client: any ProviderClient, reporter: ImportProgressReporter) async throws -> Catalog {
        var raw = try await client.fetchRawCatalog(progress: reporter)

        // Drop EPG outside the window *before* normalizing — no point spending
        // time on events we'll never show.
        let now = Date()
        let lower = now.addingTimeInterval(-Self.epgWindowPast)
        let upper = now.addingTimeInterval(Self.epgWindowFuture)
        let epgBefore = raw.epg.count
        raw.epg = raw.epg.filter { $0.stop > lower && $0.start < upper }
        if epgBefore != raw.epg.count {
            AppLog.app.info("Trimmed EPG before normalize: \(raw.epg.count) of \(epgBefore) events kept.")
        }

        let normStart = Date()
        let catalog = await normalizer.normalizeConcurrently(raw) { phase in reporter.reached(phase) }
        AppLog.app.info("Normalized in \(String(format: "%.1f", Date().timeIntervalSince(normStart)))s.")
        return catalog
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
                let forVocab = catalog
                self.vocabulary = await Task.detached { SearchVocabulary.from(catalog: forVocab) }.value
                await self.cache.save(catalog, providerID: providerID)
                AppLog.app.info("Catalog refreshed in background.")
            } catch {
                AppLog.provider.notice("Background refresh failed; keeping cached catalog.")
            }
        }
    }

    /// Kick off a background TMDB sweep so posters and ratings fill in without
    /// the user having to scroll. Rate-limited inside `MetadataService`.
    private func startMetadataWarmUp() {
        Task { [weak self] in
            guard let self else { return }
            guard await self.metadata.isEnabled else { return }
            let seeds = await self.repository.artworkSeeds(movieLimit: 600, seriesLimit: 250)
            await self.metadata.warmUp(seeds) {
                Task { @MainActor [weak self] in self?.metadataRevision += 1 }
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
        backgroundLoadTask?.cancel()
        backgroundLoadTask = nil
        await metadata.cancelWarmUp()
        providers.setActive(config.id)
        loadState = .idle
        hasLoadedOnce = false
        catalogComplete = false
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
