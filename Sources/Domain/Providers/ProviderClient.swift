import Foundation

public enum ProviderKind: String, Codable, Sendable {
    case mock
    case m3u
    case xtream
}

/// Identifies a configured provider. `id` is stable and used to derive
/// `CatalogID`s and to scope persisted data.
public struct ProviderDescriptor: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let kind: ProviderKind
    public let displayName: String

    public init(id: String, kind: ProviderKind, displayName: String) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
    }
}

/// The single seam every IPTV source implements. Everything above the
/// normalization layer depends only on this protocol, never on M3U/Xtream.
public protocol ProviderClient: Sendable {
    var descriptor: ProviderDescriptor { get }

    /// Fetch the provider's catalog in its own shape. Implementations must not
    /// block; heavy parsing belongs on a background executor.
    func fetchRawCatalog() async throws -> RawCatalog

    /// Resolve a playable URL for an item. For some providers this is a cheap
    /// passthrough; for others it hits the API. Called at playback time only.
    func resolveStreamURL(for providerItemKey: String, kind: ContentKind) async throws -> URL
}
