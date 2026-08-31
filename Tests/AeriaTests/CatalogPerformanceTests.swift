import XCTest
@testable import Aeria

/// Exercises the in-memory repository at a real provider's scale so regressions
/// in the hot paths (EPG lookup, filtering, facets, search) show up as failures,
/// not as a frozen Apple TV.
final class CatalogPerformanceTests: XCTestCase {

    // Roughly a mid-size Xtream provider.
    static let movieCount = 40_000
    static let seriesCount = 8_000
    static let channelCount = 15_000
    static let eventsPerChannel = 48

    private static let catalog: Catalog = SyntheticCatalog.make(
        movies: movieCount, series: seriesCount,
        channels: channelCount, eventsPerChannel: eventsPerChannel
    )

    func testCatalogSizeIsRealistic() {
        let c = Self.catalog
        XCTAssertEqual(c.movies.count, Self.movieCount)
        XCTAssertGreaterThan(c.epg.count, 600_000)
    }

    @MainActor
    func testRepositoryLoadAndIndexing() async {
        let repo = InMemoryCatalogRepository()
        let start = Date()
        await repo.load(Self.catalog)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 3.0, "load + index of a 60k-item catalog took \(elapsed)s")
    }

    @MainActor
    func testFacetsAreConstantTime() async {
        let repo = InMemoryCatalogRepository()
        await repo.load(Self.catalog)
        let start = Date()
        for _ in 0 ..< 200 {
            _ = await repo.availableGenres()
            _ = await repo.availableAudioLanguages()
            _ = await repo.allChannelCategories()
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.2, "facets should be cached, not recomputed")
    }

    @MainActor
    func testEPGLookupIsFast() async {
        let repo = InMemoryCatalogRepository()
        await repo.load(Self.catalog)
        let now = SyntheticCatalog.epgAnchor
        let start = Date()
        for i in 0 ..< 5_000 {
            _ = await repo.nowPlaying(forEPGID: "chan-\(i % Self.channelCount)", at: now)
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.5, "5k now-playing lookups took \(elapsed)s — index regressed?")
    }

    @MainActor
    func testNarrowingFilterOnePass() async {
        let repo = InMemoryCatalogRepository()
        await repo.load(Self.catalog)
        var filter = CatalogFilter()
        filter.genres = [.horror]
        filter.minYear = 2015
        let start = Date()
        let count = await repo.moviesCount(filter: filter)
        let page = await repo.movies(filter: filter, page: 0, pageSize: 60)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(page.count, 60)
        XCTAssertLessThan(elapsed, 0.3, "count + first page over 40k movies took \(elapsed)s")
    }

    func testSearchOverLargeCatalog() {
        let engine = SearchEngine()
        var intent = SearchIntent()
        intent.genres = [.horror]
        intent.freeText = "movie 123"
        let start = Date()
        let results = engine.search(intent, in: Self.catalog, limit: 150)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThanOrEqual(results.count, 150)
        XCTAssertLessThan(elapsed, 0.4, "search over 48k items took \(elapsed)s")
    }
}

// MARK: - Synthetic data

enum SyntheticCatalog {
    static let epgAnchor = Date(timeIntervalSince1970: 1_756_500_000)

    static func make(movies: Int, series: Int, channels: Int, eventsPerChannel: Int) -> Catalog {
        let url = URL(string: "https://example.com/s.m3u8")!
        let genres = Genre.allCases
        let langs: [Language] = [.english, .swedish, .norwegian, .german, .spanish]

        let movieList: [Movie] = (0 ..< movies).map { i in
            Movie(id: CatalogID(rawValue: "movie:\(i)"),
                  title: "Movie \(i)",
                  year: 1980 + (i % 45),
                  genres: [genres[i % genres.count]],
                  durationMinutes: 80 + (i % 80),
                  audioLanguages: [langs[i % langs.count]],
                  subtitleLanguages: [langs[(i + 1) % langs.count]],
                  quality: [.sd, .hd, .fhd, .uhd][i % 4],
                  streamURL: url)
        }
        let seriesList: [Series] = (0 ..< series).map { i in
            Series(id: CatalogID(rawValue: "series:\(i)"),
                   title: "Series \(i)",
                   year: 1990 + (i % 35),
                   genres: [genres[i % genres.count]],
                   audioLanguages: [langs[i % langs.count]],
                   subtitleLanguages: [langs[(i + 2) % langs.count]],
                   quality: .hd)
        }
        let channelList: [Channel] = (0 ..< channels).map { i in
            Channel(id: CatalogID(rawValue: "channel:\(i)"),
                    name: "Channel \(i)",
                    category: ["News", "Sport", "Movies", "Kids", "Docs", "General"][i % 6],
                    quality: .hd,
                    streamURL: url,
                    epgID: "chan-\(i)")
        }
        var epg: [EPGEvent] = []
        epg.reserveCapacity(channels * eventsPerChannel)
        for c in 0 ..< channels {
            var cursor = epgAnchor.addingTimeInterval(-6 * 3600)
            for e in 0 ..< eventsPerChannel {
                let stop = cursor.addingTimeInterval(1800)
                epg.append(EPGEvent(channelEPGID: "chan-\(c)", title: "Prog \(c)-\(e)",
                                    start: cursor, stop: stop))
                cursor = stop
            }
        }
        return Catalog(channels: channelList, movies: movieList, series: seriesList, epg: epg)
    }
}
