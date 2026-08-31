import XCTest
@testable import Aeria

final class HomeViewModelTests: XCTestCase {

    private let streamURL = URL(string: "https://example.com/x.m3u8")!

    private func movie(_ key: String, _ title: String, genres: [Genre], added: Date = .now) -> Movie {
        Movie(id: CatalogID(providerID: "p", kind: .movie, providerItemKey: key),
              title: title, genres: genres, streamURL: streamURL, addedAt: added)
    }

    private func progress(_ id: CatalogID, kind: ContentKind, fraction: Double, at date: Date) -> WatchProgress {
        WatchProgress(itemID: id, kind: kind,
                      positionSeconds: 6000 * fraction, durationSeconds: 6000, updatedAt: date)
    }

    func testMostRecentWatchedPicksTheNewestGenreTaggedMovie() {
        let old = movie("m1", "Old", genres: [.drama], added: .now)
        let new = movie("m2", "New", genres: [.action], added: .now)
        let catalog = Catalog(movies: [old, new])

        let anchor = HomeViewModel.mostRecentWatched(
            progress: [
                progress(old.id, kind: .movie, fraction: 0.4, at: Date(timeIntervalSince1970: 1_000)),
                progress(new.id, kind: .movie, fraction: 0.2, at: Date(timeIntervalSince1970: 2_000)),
            ],
            catalog: catalog
        )
        XCTAssertEqual(anchor?.id, new.id)
        XCTAssertEqual(anchor?.genres, [.action])
    }

    func testSimilarTitlesRanksBySharedGenreCountAndDropsAnchor() {
        let anchor = movie("a", "Anchor", genres: [.action, .thriller])
        let strong = movie("s", "Strong", genres: [.action, .thriller])
        let weak = movie("w", "Weak", genres: [.action, .comedy])
        let none = movie("n", "None", genres: [.documentary])

        let cards = HomeViewModel.similarTitles(
            toGenres: anchor.genres, excluding: anchor.id,
            movies: [anchor, strong, weak, none], series: [], limit: 10
        )
        XCTAssertEqual(cards.map(\.title), ["Strong", "Weak"])
    }

    func testMakeContentProducesABecauseYouWatchedRow() {
        let watched = movie("seed", "Seed", genres: [.action])
        let siblings = (0..<6).map { movie("s\($0)", "Sibling \($0)", genres: [.action]) }
        let catalog = Catalog(movies: [watched] + siblings)
        let p = progress(watched.id, kind: .movie, fraction: 0.5, at: .now)

        let content = HomeViewModel.makeContent(
            catalog: catalog, epg: [:], progress: [p],
            prefs: UserPreferences(), ratings: [:], liveNow: [], now: .now
        )
        let because = content.rows.first { $0.id == "because-\(watched.id.rawValue)" }
        XCTAssertNotNil(because)
        XCTAssertEqual(because?.title, "Because You Watched Seed")
        XCTAssertFalse(because?.cards.contains { $0.id == watched.id } ?? true)
    }
}
