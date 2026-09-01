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
        return MockCatalogData.rawCatalog()
    }

    public func resolveStreamURL(for providerItemKey: String, kind: ContentKind) async throws -> URL {
        // In the mock everything points at one of Apple's public HLS reference
        // streams so the player can actually be exercised in the Simulator.
        URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
    }
}
