import Foundation

/// Non-secret description of a configured provider. Persisted as JSON in
/// `UserDefaults`. Secrets (passwords, credential-bearing URLs) live in the
/// Keychain keyed by `id` — see `ProviderSecrets`.
public struct ProviderConfiguration: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var kind: ProviderKind
    public var displayName: String
    public var createdAt: Date

    /// Xtream: origin only, no path or credentials, e.g. `http://example.com:8080`.
    public var xtreamHost: String?
    public var xtreamUsername: String?

    /// M3U: host shown in the UI. The full credential-bearing URL is in Keychain.
    public var m3uHostForDisplay: String?

    /// EPG host shown in the UI. Full URL (may embed credentials) is in Keychain.
    public var epgHostForDisplay: String?

    public init(
        id: String = UUID().uuidString,
        kind: ProviderKind,
        displayName: String,
        createdAt: Date = .now,
        xtreamHost: String? = nil,
        xtreamUsername: String? = nil,
        m3uHostForDisplay: String? = nil,
        epgHostForDisplay: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.createdAt = createdAt
        self.xtreamHost = xtreamHost
        self.xtreamUsername = xtreamUsername
        self.m3uHostForDisplay = m3uHostForDisplay
        self.epgHostForDisplay = epgHostForDisplay
    }

    public var descriptor: ProviderDescriptor {
        ProviderDescriptor(id: id, kind: kind, displayName: displayName)
    }
}

/// Reads/writes the secret half of a provider configuration.
public enum ProviderSecrets {
    public static func xtreamPassword(for id: String) -> String? {
        KeychainStore.get("\(id).xtreamPassword")
    }
    public static func setXtreamPassword(_ value: String, for id: String) {
        KeychainStore.set(value, for: "\(id).xtreamPassword")
    }

    public static func m3uURL(for id: String) -> String? {
        KeychainStore.get("\(id).m3uURL")
    }
    public static func setM3UURL(_ value: String, for id: String) {
        KeychainStore.set(value, for: "\(id).m3uURL")
    }

    public static func epgURL(for id: String) -> String? {
        KeychainStore.get("\(id).epgURL")
    }
    public static func setEPGURL(_ value: String, for id: String) {
        KeychainStore.set(value, for: "\(id).epgURL")
    }

    public static func deleteAll(for id: String) {
        KeychainStore.delete("\(id).xtreamPassword")
        KeychainStore.delete("\(id).m3uURL")
        KeychainStore.delete("\(id).epgURL")
    }
}
