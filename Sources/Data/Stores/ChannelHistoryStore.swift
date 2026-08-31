import Foundation
import Observation

/// Remembers which live channels the viewer actually watches, so Live TV and the
/// Home "Live Now" row can float their regulars to the top. Live playback never
/// produces a resume point, so this is tracked separately from `WatchProgressStore`.
@MainActor
@Observable
public final class ChannelHistoryStore {

    private var lastWatched: [String: Date] = [:]
    private let defaults: UserDefaults
    private let key = "channelHistory.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastWatched = decoded
        }
    }

    public func record(_ id: CatalogID) {
        lastWatched[id.rawValue] = .now
        // Keep it bounded.
        if lastWatched.count > 200 {
            let survivors = lastWatched.sorted { $0.value > $1.value }.prefix(150)
            lastWatched = Dictionary(uniqueKeysWithValues: survivors.map { ($0.key, $0.value) })
        }
        persist()
    }

    public func lastWatched(_ id: CatalogID) -> Date? { lastWatched[id.rawValue] }

    /// Most-recently-watched channel ids, newest first.
    public func recent(limit: Int = 30) -> [CatalogID] {
        lastWatched.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { CatalogID(rawValue: $0.key) }
    }

    public func clear() {
        lastWatched.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(lastWatched) {
            defaults.set(data, forKey: key)
        }
    }
}
