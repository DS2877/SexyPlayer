import XCTest
@testable import SexyPlayer

final class NormalizerTests: XCTestCase {

    private func makeCatalog() -> Catalog {
        Normalizer().normalize(MockCatalogData.rawCatalog())
    }

    func testChannelsAreCleaned() {
        let catalog = makeCatalog()
        let names = Set(catalog.channels.map(\.name))
        XCTAssertTrue(names.contains("SVT1"))
        XCTAssertTrue(names.contains("TV4"))
        XCTAssertFalse(names.contains(where: { $0.contains("[") || $0.contains("1080") }))
    }

    func testChannelQualityDetected() {
        let catalog = makeCatalog()
        let vsport = catalog.channels.first { $0.name.contains("V Sport") }
        XCTAssertEqual(vsport?.quality, .uhd)
    }

    func testMoviesGetTitleYearGenre() {
        let catalog = makeCatalog()
        guard let sicario = catalog.movies.first(where: { $0.title == "Sicario" }) else {
            return XCTFail("Sicario not normalized")
        }
        XCTAssertEqual(sicario.year, 2015)
        XCTAssertTrue(sicario.genres.contains(.thriller))
        XCTAssertEqual(sicario.durationMinutes, 121)
    }

    func testHorrorMoviesWithSwedishSubtitles() {
        let catalog = makeCatalog()
        let horrorSwe = catalog.movies.filter {
            $0.genres.contains(.horror) && $0.subtitleLanguages.contains(.swedish)
        }
        // Hereditary, The Conjuring, The Babadook in the mock set.
        XCTAssertGreaterThanOrEqual(horrorSwe.count, 3)
    }

    func testSeriesReconstructedFromEpisodeNames() {
        let catalog = makeCatalog()
        guard let got = catalog.series.first(where: { $0.title == "Game of Thrones" }) else {
            return XCTFail("Game of Thrones not reconstructed")
        }
        XCTAssertEqual(got.seasons.map(\.number), [1, 2])
        let season1 = got.seasons.first { $0.number == 1 }
        XCTAssertEqual(season1?.episodes.map(\.episodeNumber), [1, 2])
    }

    func testTheLastOfUsSpansTwoSeasons() {
        let catalog = makeCatalog()
        let tlou = catalog.series.first { $0.title == "The Last of Us" }
        XCTAssertEqual(tlou?.seasons.count, 2)
        XCTAssertEqual(tlou?.episodeCount, 4)
    }

    func testEPGNormalized() {
        let catalog = makeCatalog()
        XCTAssertFalse(catalog.epg.isEmpty)
        XCTAssertTrue(catalog.epg.allSatisfy { $0.stop > $0.start })
    }

    func testDeterministic() {
        let a = Normalizer().normalize(MockCatalogData.rawCatalog())
        let b = Normalizer().normalize(MockCatalogData.rawCatalog())
        XCTAssertEqual(a.channels.map(\.name), b.channels.map(\.name))
        XCTAssertEqual(a.movies.map(\.title), b.movies.map(\.title))
        XCTAssertEqual(a.series.map(\.title), b.series.map(\.title))
    }
}
