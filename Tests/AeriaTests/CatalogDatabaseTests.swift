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

    // MARK: - Generation-stamped refresh

    func testRefreshPrunesRowsAnEarlierGenerationLeftBehind() async throws {
        let gen1 = await database.nextGeneration()
        try await database.insertMovies(
            [movie("a", "Kept A"), movie("b", "Kept B"), movie("c", "Removed C")], generation: gen1
        )
        try await database.finishGeneration(gen1)
        XCTAssertEqual(try await database.movieCount(.none, .unfiltered), 3)

        // A refresh that no longer sees "Removed C".
        let gen2 = await database.nextGeneration()
        XCTAssertEqual(gen2, gen1 + 1)
        try await database.insertMovies([movie("a", "Kept A v2"), movie("b", "Kept B")], generation: gen2)
        try await database.finishGeneration(gen2)

        let titles = try await database.movies(.none, .unfiltered, page: 0, pageSize: 10).map(\.title).sorted()
        XCTAssertEqual(titles, ["Kept A v2", "Kept B"])
        // The orphaned genre rows for "Removed C" are gone too.
        var horror = CatalogFilter.none
        horror.genres = [.drama]
        XCTAssertEqual(try await database.movieCount(horror, .unfiltered), 2)
    }

    // MARK: - Scale

    func testStaysFastAtScale() async throws {
        let count = 20_000
        let genres = Genre.allCases
        for batch in stride(from: 0, to: count, by: 2_000) {
            let movies = (batch ..< min(batch + 2_000, count)).map { i in
                movie("m\(i)", "Title \(i)", year: 1980 + i % 45, genres: [genres[i % genres.count]])
            }
            try await database.insertMovies(movies)
        }

        var filter = CatalogFilter.none
        filter.genres = [genres[0]]
        filter.minYear = 2000

        let start = Date()
        let total = try await database.movieCount(filter, .unfiltered)
        let page = try await database.movies(filter, .unfiltered, page: 3, pageSize: 60)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertGreaterThan(total, 0)
        XCTAssertLessThanOrEqual(page.count, 60)
        XCTAssertLessThan(elapsed, 0.5, "count + a deep page over 20k rows took \(elapsed)s")
    }

    func testCardProjectionKeepsWhatACardShows() async throws {
        let full = Movie(
            id: .init(rawValue: "m1"), title: "Heat", year: 1995, genres: [.crime, .thriller],
            durationMinutes: 170, audioLanguages: [.english], subtitleLanguages: [.swedish],
            quality: .fhd, countryCode: "US",
            posterURL: URL(string: "https://example.test/p.jpg"),
            synopsis: "A crew and the detective chasing them.",
            cast: ["Al Pacino", "Robert De Niro"], directors: ["Michael Mann"],
            streamURL: stream, addedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await database.insertMovies([full])

        // The card path drops cast / directors / stream url…
        let card = try await database.recentlyAddedMovies(limit: 1, .unfiltered).first
        XCTAssertEqual(card?.title, "Heat")
        XCTAssertEqual(card?.year, 1995)
        XCTAssertEqual(card?.genres, [.crime, .thriller])
        XCTAssertEqual(card?.durationMinutes, 170)
        XCTAssertEqual(card?.quality, .fhd)
        XCTAssertEqual(card?.posterURL?.absoluteString, "https://example.test/p.jpg")
        XCTAssertEqual(card?.synopsis, "A crew and the detective chasing them.")
        XCTAssertTrue(card?.cast.isEmpty ?? false)
        XCTAssertTrue(card?.directors.isEmpty ?? false)

        // …and the by-id fetch the detail screen uses still returns everything.
        let detail = try await database.movie(id: .init(rawValue: "m1"))
        XCTAssertEqual(detail?.cast, ["Al Pacino", "Robert De Niro"])
        XCTAssertEqual(detail?.directors, ["Michael Mann"])
        XCTAssertEqual(detail?.streamURL, stream)
    }

    func testRepeatedQueriesReuseTheirCompiledStatement() async throws {
        try await database.insertMovies((0..<2_000).map { movie("m\($0)", "Title \($0)") })

        // 300 point lookups: with a statement cache this is dominated by the
        // lookups themselves, not by re-compiling the same SQL 300 times.
        let start = Date()
        for i in 0 ..< 300 {
            _ = try await database.movie(id: .init(rawValue: "m\(i % 2_000)"))
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0, "300 cached point lookups took \(elapsed)s")
    }

    func testReadsRunWhileAWriteIsInFlight() async throws {
        try await database.insertMovies((0..<500).map { movie("seed\($0)", "Seed \($0)") })

        // Kick off a big write, then hammer reads — they must not be blocked
        // until the write finishes (separate connections + WAL).
        let writeBatch = (0..<8_000).map { movie("w\($0)", "W \($0)") }
        async let bigWrite: Void = database.insertMovies(writeBatch)

        let start = Date()
        for _ in 0 ..< 40 {
            _ = try await database.movie(id: .init(rawValue: "seed0"))
        }
        let readElapsed = Date().timeIntervalSince(start)
        try await bigWrite

        XCTAssertLessThan(readElapsed, 2.0, "40 point reads took \(readElapsed)s while a write ran")
    }
}
