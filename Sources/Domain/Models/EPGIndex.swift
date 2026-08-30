import Foundation

/// The EPG grouped by channel id, each list sorted by start time. Built once by
/// the repository; feature code windows and queries it locally instead of
/// scanning the flat `Catalog.epg` array (which is O(all programmes) per call
/// and unusable at a real provider's scale).
public typealias EPGIndex = [String: [EPGEvent]]

public extension Dictionary where Key == String, Value == [EPGEvent] {

    /// Events on a channel overlapping `window`, in start order.
    func events(forChannel epgID: String, in window: DateInterval) -> [EPGEvent] {
        guard let events = self[epgID] else { return [] }
        return events.filter { $0.stop > window.start && $0.start < window.end }
    }

    /// The programme airing on a channel at `date`, if any. Binary search over
    /// the start-sorted list.
    func nowPlaying(forChannel epgID: String, at date: Date) -> EPGEvent? {
        guard let events = self[epgID], !events.isEmpty else { return nil }
        var low = 0, high = events.count - 1, candidate = -1
        while low <= high {
            let mid = (low + high) / 2
            if events[mid].start <= date { candidate = mid; low = mid + 1 }
            else { high = mid - 1 }
        }
        guard candidate >= 0 else { return nil }
        let event = events[candidate]
        return event.isLive(at: date) ? event : nil
    }
}
