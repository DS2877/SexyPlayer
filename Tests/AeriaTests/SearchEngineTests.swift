import XCTest
@testable import Aeria

final class SearchEngineTests: XCTestCase {

    private let engine = SearchEngine()
    private lazy var catalog = Normalizer().normalize(MockCatalogData.rawCatalog())

    func testGenrePlusSubtitleFilter() {
        let intent = SearchIntent(kinds: [.movie], genres: [.horror], subtitleLanguages: [.swedish])
        let results = engine.search(intent, in: catalog)
        XCTAssertFalse(results.isEmpty)
        for r in results {
            guard case .movie(let m) = r.item else { return XCTFail("expected movie") }
            XCTAssertTrue(m.genres.contains(.horror))
            XCTAssertTrue(m.subtitleLanguages.contains(.swedish))
        }
    }

    func testFreeTextRanksExactTitleFirst() {
        let intent = SearchIntent(freeText: "nosferatu")
        let results = engine.search(intent, in: catalog)
        XCTAssertEqual(results.first?.title, "Nosferatu")
    }

    func testYearConstraint() {
        let intent = SearchIntent(kinds: [.movie], minYear: 1960)
        let results = engine.search(intent, in: catalog)
        for r in results {
            guard case .movie(let m) = r.item else { continue }
            XCTAssertGreaterThanOrEqual(m.year ?? 0, 1960)
        }
        XCTAssertTrue(results.contains { $0.title == "Night of the Living Dead" })
        XCTAssertFalse(results.contains { $0.title == "Metropolis" })
    }

    func testDurationConstraint() {
        let intent = SearchIntent(kinds: [.movie], maxDurationMinutes: 70)
        let results = engine.search(intent, in: catalog)
        for r in results {
            guard case .movie(let m) = r.item, let d = m.durationMinutes else { continue }
            XCTAssertLessThanOrEqual(d, 70)
        }
    }

    func testEmptyIntentReturnsMoviesAndSeriesNotChannels() {
        let results = engine.search(.empty, in: catalog)
        XCTAssertTrue(results.contains { $0.kind == .movie })
        XCTAssertTrue(results.contains { $0.kind == .series })
        XCTAssertFalse(results.contains { $0.kind == .liveChannel })
    }

    func testNoFalsePositivesForAbsentContent() {
        let intent = SearchIntent(freeText: "the sopranos")
        let results = engine.search(intent, in: catalog)
        XCTAssertFalse(results.contains { $0.title.localizedCaseInsensitiveContains("sopranos") })
    }

    func testEndToEndFromNaturalLanguage() async throws {
        let parser = DeterministicQueryParser()
        let intent = try await parser.parse("scary movies with swedish subtitles", vocabulary: .init())
        let results = engine.search(intent, in: catalog)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.kind == .movie })
    }
}
