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
    private let normalizer: Normalizer
    private var provider: any ProviderClient

    // State
    public private(set) var loadState: LoadState = .idle
    public private(set) var activeProvider: ProviderDescriptor
    public private(set) var vocabulary: SearchVocabulary = .init()

    public init(provider: any ProviderClient) {
        self.provider = provider
        self.activeProvider = provider.descriptor
        self.repository = InMemoryCatalogRepository()
        self.searchEngine = SearchEngine()
        self.aiService = AIService(mode: .onDeviceOnly)
        self.normalizer = Normalizer()
    }

    /// The default app wiring: the bundled demo provider.
    public static func live() -> AppEnvironment {
        AppEnvironment(provider: MockProviderClient())
    }

    /// Fetch + normalise + load the active provider's catalog.
    public func bootstrap(forceReload: Bool = false) async {
        if case .loading = loadState { return }
        if case .ready = loadState, !forceReload { return }

        loadState = .loading
        do {
            let raw = try await provider.fetchRawCatalog()
            let normalizer = self.normalizer
            // Normalisation is pure and potentially heavy — run it off the main actor.
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

    /// Swap the active provider (used by provider setup in M6).
    public func switchProvider(_ newProvider: any ProviderClient) async {
        provider = newProvider
        activeProvider = newProvider.descriptor
        loadState = .idle
        await bootstrap(forceReload: true)
    }

    public func setAIMode(_ mode: AIService.Mode) async {
        await aiService.setMode(mode)
    }
}
