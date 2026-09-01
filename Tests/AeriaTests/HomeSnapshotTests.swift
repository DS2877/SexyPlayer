import XCTest
@testable import Aeria

/// The Home snapshot is what makes a relaunch paint instantly, so it has to
/// round-trip losslessly and refuse anything it shouldn't show.
final class HomeSnapshotTests: XCTestCase {

    override func tearDown() {
        HomeSnapshotStore.clear()
        super.tearDown()
    }

    private func card(_ id: String, _ title: String, kind: HomeCard.Kind = .movie) -> HomeCard {
        HomeCard(id: .init(rawValue: id), kind: kind, title: title, subtitle: "2024 · Drama",
                 artworkURL: URL(string: "https://example.test/\(id).jpg"), year: 2024,
                 progress: 0.4, resumeItemID: .init(rawValue: id))
    }

    private var sample: HomeContent {
        HomeContent(
            heroes: [card("h1", "Hero One")],
            rows: [
                HomeRow(id: "continueWatching", title: "Continue Watching", subtitle: nil,
                        cards: [card("m1", "Half Watched")]),
                HomeRow(id: "recent-channels", title: "Recently Watched", subtitle: nil,
                        cards: [card("c1", "SVT1", kind: .channel)]),
            ],
            tonight: [
                TonightItem(id: "t1", channelID: .init(rawValue: "c1"), time: "20:00",
                            programTitle: "Rapport", channelName: "SVT1", isLiveNow: true),
            ]
        )
    }

    func testRoundTripsEveryField() throws {
        HomeSnapshotStore.save(sample, providerID: "p1")
        let loaded = try XCTUnwrap(HomeSnapshotStore.load(providerID: "p1"))

        XCTAssertEqual(loaded.heroes.first?.title, "Hero One")
        XCTAssertEqual(loaded.rows.count, 2)
        XCTAssertEqual(loaded.rows.first?.cards.first?.progress, 0.4)
        XCTAssertEqual(loaded.rows.first?.cards.first?.resumeItemID?.rawValue, "m1")
        XCTAssertEqual(loaded.rows.last?.cards.first?.kind, .channel)
        XCTAssertEqual(loaded.tonight.first?.programTitle, "Rapport")
        XCTAssertEqual(loaded.tonight.first?.isLiveNow, true)
    }

    func testRefusesAnotherProvidersScreen() {
        HomeSnapshotStore.save(sample, providerID: "p1")
        XCTAssertNil(HomeSnapshotStore.load(providerID: "p2"))
    }

    func testDoesNotPersistAnEmptyScreen() {
        HomeSnapshotStore.save(.empty, providerID: "p1")
        XCTAssertNil(HomeSnapshotStore.load(providerID: "p1"))
    }

    func testClearRemovesIt() {
        HomeSnapshotStore.save(sample, providerID: "p1")
        HomeSnapshotStore.clear()
        XCTAssertNil(HomeSnapshotStore.load(providerID: "p1"))
    }

    func testEmptyContentIsReportedEmpty() {
        XCTAssertTrue(HomeContent.empty.isEmpty)
        XCTAssertFalse(sample.isEmpty)
    }
}
