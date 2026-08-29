import Foundation

/// A `ProviderClient` backed by `MockCatalogData`. Used for the Simulator build
/// and for App Store review, where a reviewer must be able to exercise the app
/// without real IPTV credentials.
public struct MockProviderClient: ProviderClient {

    public let descriptor = ProviderDescriptor(
        id: MockCatalogData.providerID,
        kind: .mock,
        displayName: "Demo Library"
    )

    /// Simulated latency so loading states are visible during development.
    private let artificialDelay: Duration

    public init(artificialDelay: Duration = .milliseconds(600)) {
        self.artificialDelay = artificialDelay
    }

    public func fetchRawCatalog(progress: ImportProgressReporter) async throws -> RawCatalog {
        progress.reached(.connecting)
        for phase in ImportPhase.checklist {
            try await Task.sleep(for: artificialDelay / 4)
            progress.reached(phase)
        }
        progress.reached(.finalizing)
        return MockCatalogData.rawCatalog()
    }

    public func resolveStreamURL(for providerItemKey: String, kind: ContentKind) async throws -> URL {
        // In the mock everything points at a short public-domain test stream so
        // the player can actually be exercised in the Simulator.
        URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!
    }
}
