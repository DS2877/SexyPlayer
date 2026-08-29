import Foundation
import OSLog

/// Thin wrapper over `os.Logger` with a fixed subsystem and named categories.
///
/// **Never** pass credentials, tokens, or private stream URLs here. Use
/// `redacting(_:)` for anything that might contain them.
public enum AppLog {
    private static let subsystem = "com.sexyplayer.app"

    public static let app       = Logger(subsystem: subsystem, category: "app")
    public static let provider  = Logger(subsystem: subsystem, category: "provider")
    public static let normalize = Logger(subsystem: subsystem, category: "normalize")
    public static let search    = Logger(subsystem: subsystem, category: "search")
    public static let ai        = Logger(subsystem: subsystem, category: "ai")
    public static let player    = Logger(subsystem: subsystem, category: "player")

    /// Reduce a URL to scheme + host so it can be logged without leaking a
    /// private path or query (which for Xtream contains credentials).
    public static func redacting(_ url: URL?) -> String {
        guard let url, let host = url.host() else { return "<url>" }
        return "\(url.scheme ?? "?")://\(host)/…"
    }
}
