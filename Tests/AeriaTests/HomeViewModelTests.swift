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

    func testRecentlyWatchedChannelsRow() {
        let url = URL(string: "https://x/s")!
        func ch(_ key: String, _ name: String) -> Channel {
            Channel(id: CatalogID(providerID: "p", kind: .liveChannel, providerItemKey: key),
                    name: name, category: "General", streamURL: url)
        }
        let a = ch("a", "SVT1"), b = ch("b", "TV4"), c = ch("c", "Kanal 5")
        let catalog = Catalog(channels: [a, b, c])

        let content = HomeViewModel.makeContent(
            catalog: catalog, epg: [:], progress: [],
            prefs: UserPreferences(), ratings: [:], liveNow: [],
            recentChannelIDs: [b.id, a.id], now: .now
        )
        let row = content.rows.first { $0.id == "recent-channels" }
        XCTAssertEqual(row?.title, "Recently Watched")
        XCTAssertEqual(row?.cards.map(\.title), ["TV4", "SVT1"])
    }

    func testTopRatedSeriesCanHeadlineTheHero() {
        let m = movie("m", "Fine Movie", genres: [.drama])
        let seriesID = CatalogID(providerID: "p", kind: .series, providerItemKey: "s")
        let series = Series(id: seriesID, title: "Great Show", genres: [.drama], seasons: [])
        let catalog = Catalog(movies: [m], series: [series])

        let content = HomeViewModel.makeContent(
            catalog: catalog, epg: [:], progress: [],
            prefs: UserPreferences(), ratings: [m.id.rawValue: 6.0, seriesID.rawValue: 9.1],
            liveNow: [], now: .now
        )
        XCTAssertEqual(content.heroes.first?.id, seriesID)
        XCTAssertEqual(content.heroes.first?.kind, .series)
    }

    func testMyListRowFollowsFavouriteOrder() {
        let a = movie("a", "Alpha", genres: [.drama])
        let b = movie("b", "Bravo", genres: [.comedy])
        let sID = CatalogID(providerID: "p", kind: .series, providerItemKey: "s")
        let s = Series(id: sID, title: "Charlie", genres: [.drama], seasons: [])
        let catalog = Catalog(movies: [a, b], series: [s])

        let content = HomeViewModel.makeContent(
            catalog: catalog, epg: [:], progress: [],
            prefs: UserPreferences(), ratings: [:], liveNow: [], now: .now,
            favoriteIDs: [b.id, sID, a.id]
        )
        let row = content.rows.first { $0.id == HomeRowKind.myList.rawValue }
        XCTAssertEqual(row?.title, "My List")
        XCTAssertEqual(row?.cards.map(\.title), ["Bravo", "Charlie", "Alpha"])
    }

    func testMyListRowAbsentWithoutFavourites() {
        let a = movie("a", "Alpha", genres: [.drama])
        let content = HomeViewModel.makeContent(
            catalog: Catalog(movies: [a]), epg: [:], progress: [],
            prefs: UserPreferences(), ratings: [:], liveNow: [], now: .now
        )
        XCTAssertNil(content.rows.first { $0.id == HomeRowKind.myList.rawValue })
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
