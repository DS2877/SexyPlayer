import XCTest
@testable import Aeria

/// Round-trips the SQLite catalog store: schema, inserts, the paged/filtered
/// query surface, the A–Z rails, EPG windowing, and search.
final class CatalogDatabaseTests: XCTestCase {

    private var tempURL: URL!
    private var database: CatalogDatabase!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-test-\(UUID().uuidString).sqlite3")
        database = try CatalogDatabase(path: tempURL)
    }

    override func tearDown() async throws {
        database = nil
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: tempURL.path + suffix))
        }
        try await super.tearDown()
    }

    // MARK: - Fixtures

    private let stream = URL(string: "https://example.test/stream")!

    private func movie(
        _ id: String, _ title: String, year: Int? = 2020, genres: [Genre] = [.drama],
        added: Date? = Date(timeIntervalSince1970: 1_700_000_000), adult: Bool = false, country: String? = "SE"
    ) -> Movie {
        Movie(id: .init(rawValue: id), title: title, year: year, genres: genres,
              audioLanguages: [.english], subtitleLanguages: [.swedish],
              countryCode: country, streamURL: stream, addedAt: added, isAdult: adult)
    }

    private func channel(_ id: String, _ name: String, country: String?, num: Int, epg: String? = nil) -> Channel {
        Channel(id: .init(rawValue: id), name: name, category: "General",
                countryCode: country, streamURL: stream, epgID: epg, sortIndex: num)
    }

    // MARK: - Schema

    func testOpensAndReportsNotReady() async throws {
        let ready = await database.importIsComplete()
        XCTAssertFalse(ready)
    }

    func testSchemaSurvivesReopen() async throws {
        try await database.insertMovies([movie("m1", "Alpha")])
        database = nil
        database = try CatalogDatabase(path: tempURL)
        let count = try await database.movieCount(.none, .unfiltered)
        XCTAssertEqual(count, 1)
    }

    // MARK: - Movies: count / page / by id

    func testInsertAndCountMovies() async throws {
        try await database.insertMovies([
            movie("m1", "Alpha"), movie("m2", "Beta"), movie("m3", "Gamma"),
        ])
        let count = try await database.movieCount(.none, .unfiltered)
        XCTAssertEqual(count, 3)

        let fetched = try await database.movie(id: .init(rawValue: "m2"))
        XCTAssertEqual(fetched?.title, "Beta")
        XCTAssertEqual(fetched?.audioLanguages, [.english])
        XCTAssertEqual(fetched?.genres, [.drama])
    }

    func testPaginationIsStableAndOrdered() async throws {
        let movies = (1...25).map { movie(String(format: "m%02d", $0), "Title \($0)") }
        try await database.insertMovies(movies)

        var filter = CatalogFilter.none
        filter.sort = .titleAscending
        let page0 = try await database.movies(filter, .unfiltered, page: 0, pageSize: 10)
        let page1 = try await database.movies(filter, .unfiltered, page: 1, pageSize: 10)
        XCTAssertEqual(page0.count, 10)
        XCTAssertEqual(page1.count, 10)
        XCTAssertTrue(Set(page0.map(\.id)).isDisjoint(with: Set(page1.map(\.id))))
        // "Title 1" < "Title 10" < "Title 2" under a plain fold sort.
        XCTAssertEqual(page0.first?.title, "Title 1")
    }

    // MARK: - Filtering

    func testGenreFilter() async throws {
        try await database.insertMovies([
            movie("m1", "Horror One", genres: [.horror]),
            movie("m2", "Drama One", genres: [.drama]),
            movie("m3", "Both", genres: [.horror, .comedy]),
        ])
        var filter = CatalogFilter.none
        filter.genres = [.horror]
        let count = try await database.movieCount(filter, .unfiltered)
        XCTAssertEqual(count, 2)
    }

    func testYearFilterExcludesNilYear() async throws {
        try await database.insertMovies([
            movie("m1", "Old", year: 1990),
            movie("m2", "New", year: 2022),
            movie("m3", "Undated", year: nil),
        ])
        var filter = CatalogFilter.none
        filter.minYear = 2000
        let titles = try await database.movies(filter, .unfiltered, page: 0, pageSize: 10).map(\.title)
        XCTAssertEqual(titles, ["New"])
    }

    func testAdultAndRegionScope() async throws {
        try await database.insertMovies([
            movie("m1", "Clean", country: "SE"),
            movie("m2", "Adult", adult: true, country: "SE"),
            movie("m3", "Foreign", country: "DE"),
        ])
        let all = try await database.movieCount(.none, .init(showAdult: true, allRegions: true))
        XCTAssertEqual(all, 3)

        let noAdult = try await database.movieCount(.none, .init(showAdult: false, allRegions: true))
        XCTAssertEqual(noAdult, 2)

        let nordicOnly = try await database.movieCount(.none, .init(showAdult: true, allRegions: false))
        XCTAssertEqual(nordicOnly, 2)   // "Foreign" (DE) dropped
    }

    // MARK: - A–Z rails

    func testTitleAnchors() async throws {
        try await database.insertMovies([
            movie("m1", "Apple"), movie("m2", "Avocado"),
            movie("m3", "Banana"), movie("m4", "9 Lives"),
        ])
        var filter = CatalogFilter.none
        filter.sort = .titleAscending
        let titles = try await database.movieTitlesInOrder(filter, .unfiltered)
        let anchors = SQLiteCatalogRepository.anchors(titles)
        XCTAssertEqual(anchors.map(\.letter), ["#", "A", "B"])
        XCTAssertEqual(anchors.first { $0.letter == "B" }?.index, 3)
    }

    // MARK: - Channels

    func testChannelForYouOrder() async throws {
        try await database.insertChannels([
            channel("gb1", "BBC One", country: "GB", num: 1),
            channel("se2", "SVT2", country: "SE", num: 2),
            channel("no1", "NRK1", country: "NO", num: 1),
            channel("se1", "SVT1", country: "SE", num: 1),
        ], homeRegions: ["SE"])

        var order = try await database.channels(category: nil, sort: .number, .unfiltered, page: 0, pageSize: 10).map(\.name)
        XCTAssertEqual(order, ["SVT1", "SVT2", "NRK1", "BBC One"])

        try await database.updateRecentChannels([.init(rawValue: "gb1")])
        order = try await database.channels(category: nil, sort: .number, .unfiltered, page: 0, pageSize: 10).map(\.name)
        XCTAssertEqual(order.first, "BBC One")
    }

    // MARK: - Series & episodes

    func testSeriesRoundTripWithSeasons() async throws {
        let seriesID = CatalogID(rawValue: "s1")
        let episodes = [
            Episode(id: .init(rawValue: "s1e1"), seriesID: seriesID, seasonNumber: 1, episodeNumber: 1,
                    title: "Pilot", streamURL: stream),
            Episode(id: .init(rawValue: "s1e2"), seriesID: seriesID, seasonNumber: 1, episodeNumber: 2,
                    title: "Second", streamURL: stream),
        ]
        let series = Series(id: seriesID, title: "The Show", year: 2019, genres: [.drama],
                            seasons: [Season(seriesID: seriesID, number: 1, episodes: episodes)])
        try await database.insertSeries([series])

        let fetched = try await database.series(id: seriesID)
        XCTAssertEqual(fetched?.seasons.first?.episodes.count, 2)
        XCTAssertEqual(fetched?.episodeCount, 2)

        let episode = try await database.episode(id: .init(rawValue: "s1e2"))
        XCTAssertEqual(episode?.title, "Second")
    }

    // MARK: - EPG

    func testEPGWindowingAndNowPlaying() async throws {
        let now = Date()
        let events = [
            EPGEvent(channelEPGID: "svt1.se", title: "Earlier",
                     start: now.addingTimeInterval(-7200), stop: now.addingTimeInterval(-3600)),
            EPGEvent(channelEPGID: "svt1.se", title: "Now",
                     start: now.addingTimeInterval(-600), stop: now.addingTimeInterval(600)),
            EPGEvent(channelEPGID: "svt1.se", title: "WayLater",
                     start: now.addingTimeInterval(96 * 3600), stop: now.addingTimeInterval(97 * 3600)),
        ]
        try await database.insertEPG(events, window: EPGWindow.current(now: now))

        // "WayLater" is outside the ±window and never stored.
        let count = try await database.epgEvents(
            epgID: "svt1.se",
            in: DateInterval(start: now.addingTimeInterval(-100 * 3600), end: now.addingTimeInterval(200 * 3600))
        ).count
        XCTAssertEqual(count, 2)

        let live = try await database.nowPlaying(epgID: "svt1.se", at: now)
        XCTAssertEqual(live?.title, "Now")
    }

    // MARK: - Search

    func testSearchRanksExactTitleFirst() async throws {
        try await database.insertMovies([
            movie("m1", "The Matrix", genres: [.sciFi]),
            movie("m2", "Matrix Reloaded", genres: [.sciFi]),
            movie("m3", "Unrelated", genres: [.comedy]),
        ])
        let repo = SQLiteCatalogRepository(database: database)
        let results = await repo.search(SearchIntent(freeText: "matrix"), limit: 10)
        // "Matrix Reloaded" is a prefix match (+6); "The Matrix" only a
        // substring (+3), so the prefix hit ranks first.
        XCTAssertEqual(results.first?.title, "Matrix Reloaded")
        XCTAssertTrue(results.contains { $0.title == "The Matrix" })
        XCTAssertFalse(results.contains { $0.title == "Unrelated" })
    }

    // MARK: - Resume points

    func testResumePointsResolveThroughStore() async throws {
        try await database.insertMovies([movie("m1", "Half Watched")])
        let repo = SQLiteCatalogRepository(database: database)
        let progress = [
            WatchProgress(itemID: .init(rawValue: "m1"), kind: .movie,
                          positionSeconds: 1800, durationSeconds: 3600, updatedAt: Date()),
        ]
        let points = await repo.resumePoints(progress: progress, limit: 10)
        XCTAssertEqual(points.first?.primaryTitle, "Half Watched")
    }
}
