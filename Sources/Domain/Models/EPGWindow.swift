import Foundation

/// The slice of the electronic programme guide the app keeps — in memory, on
/// disk, and (crucially) *while parsing the provider's XMLTV*.
///
/// A real provider's XMLTV is millions of programmes and, decompressed, hundreds
/// of megabytes. The UI only ever shows "on now", "tonight" and roughly a day
/// ahead, so the guide is windowed **at the source**: the XMLTV parser skips
/// programmes outside this window and never allocates them. Memory then never
/// scales with the size of the feed.
public enum EPGWindow {
    /// Keep programmes that started up to this long ago (so something that began
    /// before "now" still reads as on-air).
    public static let past: TimeInterval = 2 * 3600
    /// Keep programmes starting up to this far ahead.
    public static let future: TimeInterval = 32 * 3600

    /// The concrete window relative to `now`.
    public static func current(now: Date = Date()) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(-past),
                     end: now.addingTimeInterval(future))
    }

    /// True when `[start, stop)` overlaps the window.
    public static func contains(start: Date, stop: Date, now: Date = Date()) -> Bool {
        stop > now.addingTimeInterval(-past) && start < now.addingTimeInterval(future)
    }
}
