import XCTest
@testable import Aeria

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
        guard let notld = catalog.movies.first(where: { $0.title == "Night of the Living Dead" }) else {
            return XCTFail("Night of the Living Dead not normalized")
        }
        XCTAssertEqual(notld.year, 1968)
        XCTAssertTrue(notld.genres.contains(.horror))
        XCTAssertEqual(notld.durationMinutes, 96)
    }

    func testHorrorMoviesWithSwedishSubtitles() {
        let catalog = makeCatalog()
        let horrorSwe = catalog.movies.filter {
            $0.genres.contains(.horror) && $0.subtitleLanguages.contains(.swedish)
        }
        // Caligari, Häxan, Carnival of Souls carry a Swedish subtitle tag.
        XCTAssertGreaterThanOrEqual(horrorSwe.count, 3)
    }

    func testSeriesReconstructedFromEpisodeNames() {
        let catalog = makeCatalog()
        guard let holmes = catalog.series.first(where: { $0.title == "Sherlock Holmes" }) else {
            return XCTFail("Sherlock Holmes not reconstructed")
        }
        XCTAssertEqual(holmes.seasons.map(\.number), [1])
        let season1 = holmes.seasons.first { $0.number == 1 }
        XCTAssertEqual(season1?.episodes.map(\.episodeNumber), [1, 2, 3])
    }

    func testCiscoKidSpansTwoSeasons() {
        let catalog = makeCatalog()
        let cisco = catalog.series.first { $0.title == "The Cisco Kid" }
        XCTAssertEqual(cisco?.seasons.count, 2)
        XCTAssertEqual(cisco?.episodeCount, 3)
    }

    func testEPGNormalized() {
        let catalog = makeCatalog()
        XCTAssertFalse(catalog.epg.isEmpty)
        XCTAssertTrue(catalog.epg.allSatisfy { $0.stop > $0.start })
    }

    func testSeriesShellsCarryProviderKey() {
        let raw = RawCatalog(
            providerID: "p",
            seriesShells: [
                RawSeriesShell(providerKey: "42", name: "The Wire (2002)", plot: "Baltimore.", genreText: "Crime, Drama")
            ]
        )
        let catalog = Normalizer().normalize(raw)
        let wire = catalog.series.first { $0.title == "The Wire" }
        XCTAssertEqual(wire?.providerSeriesKey, "42")
        XCTAssertEqual(wire?.year, 2002)
        XCTAssertTrue(wire?.genres.contains(.crime) ?? false)
        XCTAssertFalse(wire?.hasEpisodes ?? true)
    }

    func testOnDemandSeasonsFromExplicitEpisodes() {
        let seriesID = CatalogID(providerID: "p", kind: .series, providerItemKey: "shell:42")
        let raw = [
            RawSeriesEpisode(providerKey: "e1", name: "Pilot", groupTitle: nil, logo: nil,
                             streamURL: "http://x/1.mp4", explicitSeason: 1, explicitEpisode: 1),
            RawSeriesEpisode(providerKey: "e2", name: "Old Cases", groupTitle: nil, logo: nil,
                             streamURL: "http://x/2.mp4", explicitSeason: 1, explicitEpisode: 2),
        ]
        let seasons = Normalizer().seasons(forEpisodes: raw, seriesID: seriesID, providerID: "p")
        XCTAssertEqual(seasons.count, 1)
        XCTAssertEqual(seasons.first?.episodes.map(\.episodeNumber), [1, 2])
        XCTAssertEqual(seasons.first?.episodes.first?.title, "Pilot")
    }

    func testDeterministic() {
        let a = Normalizer().normalize(MockCatalogData.rawCatalog())
        let b = Normalizer().normalize(MockCatalogData.rawCatalog())
        XCTAssertEqual(a.channels.map(\.name), b.channels.map(\.name))
        XCTAssertEqual(a.movies.map(\.title), b.movies.map(\.title))
        XCTAssertEqual(a.series.map(\.title), b.series.map(\.title))
    }
}
