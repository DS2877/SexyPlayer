import Foundation

/// Lightweight runtime instrumentation so large-library behaviour can be judged
/// from the logs on a real device.
enum RuntimeStats {

    /// Approximate megabytes the app can still allocate before the OS jetsams
    /// it. `0` when the platform can't report it (some Simulator configs).
    static var memoryHeadroomMB: Int {
        let bytes = os_proc_available_memory()
        return bytes > 0 ? Int(bytes / (1024 * 1024)) : 0
    }

    static func catalogSummary(_ catalog: Catalog) -> String {
        var parts = [
            "\(catalog.channels.count) channels",
            "\(catalog.movies.count) movies",
            "\(catalog.series.count) series",
            "\(catalog.epg.count) EPG events",
        ]
        let headroom = memoryHeadroomMB
        if headroom > 0 { parts.append("~\(headroom) MB headroom") }
        return parts.joined(separator: " · ")
    }
}
