import XCTest
@testable import Aeria

/// Favorites and History reload off these revisions instead of re-querying on
/// every back-navigation, so the revision has to move for real changes and
/// stay put for everything else.
@MainActor
final class StoreRevisionTests: XCTestCase {

    private func id(_ raw: String) -> CatalogID { .init(rawValue: raw) }

    private func freshDefaults(_ name: String) -> UserDefaults {
        UserDefaults(suiteName: "aeria.tests.\(name).\(UUID().uuidString)")!
    }

    // MARK: - Favorites

    func testFavoritesRevisionTracksTheSetNotTheCount() {
        let store = FavoritesStore(defaults: freshDefaults("fav"))
        let empty = store.revision

        store.toggle(id: id("a"), kind: .movie)
        let oneItem = store.revision
        XCTAssertNotEqual(oneItem, empty)

        // Swap one favourite for another: the count is unchanged, so a
        // count-based key would have missed this entirely.
        store.toggle(id: id("a"), kind: .movie)      // remove
        store.toggle(id: id("b"), kind: .movie)      // add
        XCTAssertEqual(store.all().count, 1)
        XCTAssertNotEqual(store.revision, oneItem)
    }

    func testFavoritesRevisionIsStableWithoutChanges() {
        let store = FavoritesStore(defaults: freshDefaults("fav-stable"))
        store.toggle(id: id("a"), kind: .movie)
        store.toggle(id: id("b"), kind: .series)
        let before = store.revision
        _ = store.all()
        _ = store.isFavorite(id("a"))
        XCTAssertEqual(store.revision, before)
    }

    // MARK: - Watch progress

    func testWatchRevisionMovesWhenAnExistingItemAdvances() {
        let store = WatchProgressStore(defaults: freshDefaults("watch"))
        store.record(id: id("m1"), kind: .movie, positionSeconds: 100, durationSeconds: 6000)
        let first = store.revision

        // Same item, further in — the count doesn't change, but the screen must.
        store.record(id: id("m1"), kind: .movie, positionSeconds: 2400, durationSeconds: 6000)
        XCTAssertEqual(store.allEntries().count, 1)
        XCTAssertNotEqual(store.revision, first)
    }

    func testWatchRevisionIsStableWithoutChanges() {
        let store = WatchProgressStore(defaults: freshDefaults("watch-stable"))
        store.record(id: id("m1"), kind: .movie, positionSeconds: 100, durationSeconds: 6000)
        let before = store.revision
        _ = store.history()
        _ = store.allEntries()
        XCTAssertEqual(store.revision, before)
    }
}
