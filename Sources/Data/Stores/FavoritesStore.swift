import Foundation
import Observation

/// User's favourited items. `UserDefaults`-backed for M2 (see `WatchProgressStore`).
@MainActor
@Observable
public final class FavoritesStore {

    private var byID: [String: Favorite] = [:]
    private let defaults: UserDefaults
    private let storageKey = "favorites.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func isFavorite(_ id: CatalogID) -> Bool {
        byID[id.rawValue] != nil
    }

    public func all() -> [Favorite] {
        byID.values.sorted { $0.addedAt > $1.addedAt }
    }

    public func toggle(id: CatalogID, kind: ContentKind) {
        if byID[id.rawValue] != nil {
            byID[id.rawValue] = nil
        } else {
            byID[id.rawValue] = Favorite(itemID: id, kind: kind)
        }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data)
        else { return }
        byID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.itemID.rawValue, $0) })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Array(byID.values)) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
