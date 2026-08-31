import XCTest
@testable import Aeria

final class PreferencesTests: XCTestCase {

    func testAdultDetection() {
        XCTAssertTrue(AdultContentDetector.isAdult(name: "Some Movie", groupTitle: "XXX Movies"))
        XCTAssertTrue(AdultContentDetector.isAdult(name: "Late Night 18+", groupTitle: "Entertainment"))
        XCTAssertTrue(AdultContentDetector.isAdult(name: "Adults Only Feature", groupTitle: nil))
        XCTAssertFalse(AdultContentDetector.isAdult(name: "The Grand Budapest Hotel", groupTitle: "Movies | Comedy"))
        XCTAssertFalse(AdultContentDetector.isAdult(name: "Adulthood", groupTitle: "Drama"))
    }

    @MainActor
    func testPreferencesRoundTrip() {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = PreferencesStore(defaults: defaults)
        store.update {
            $0.preferredAudioLanguages = [.english, .swedish]
            $0.preferredSubtitleLanguage = .swedish
            $0.hideAdultContent = false
            $0.homeRows = [.continueWatching, .movies]
        }
        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.preferences.preferredAudioLanguages, [.english, .swedish])
        XCTAssertEqual(reloaded.preferences.preferredSubtitleLanguage, .swedish)
        XCTAssertFalse(reloaded.preferences.hideAdultContent)
        XCTAssertEqual(reloaded.preferences.homeRows, [.continueWatching, .movies])
    }

    @MainActor
    func testRepositoryHidesAdult() async {
        let catalog = Catalog(
            channels: [],
            movies: [
                Movie(id: .init(rawValue: "m1"), title: "Clean", streamURL: URL(string: "https://x/1")!),
                Movie(id: .init(rawValue: "m2"), title: "Adult", streamURL: URL(string: "https://x/2")!, isAdult: true),
            ],
            series: [], epg: []
        )
        let repo = InMemoryCatalogRepository()
        await repo.load(catalog)
        await repo.setHideAdult(true)
        let count = await repo.moviesCount(filter: .none)
        XCTAssertEqual(count, 1)
        await repo.setHideAdult(false)
        let all = await repo.moviesCount(filter: .none)
        XCTAssertEqual(all, 2)
    }
}
