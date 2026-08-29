import XCTest
@testable import SexyPlayer

final class EpisodeParserTests: XCTestCase {

    func testStandardSxxExx() {
        let p = EpisodeParser.parse("The Last of Us S01E03")
        XCTAssertEqual(p, .init(seriesTitle: "The Last of Us", season: 1, episode: 3))
    }

    func testDottedRelease() {
        let p = EpisodeParser.parse("Game.of.Thrones.S01E01.Winter.Is.Coming.1080p")
        XCTAssertEqual(p?.seriesTitle, "Game of Thrones")
        XCTAssertEqual(p?.season, 1)
        XCTAssertEqual(p?.episode, 1)
    }

    func testCrossFormat() {
        let p = EpisodeParser.parse("The Last of Us 2x01 - Future Days")
        XCTAssertEqual(p, .init(seriesTitle: "The Last of Us", season: 2, episode: 1))
    }

    func testWordyFormat() {
        let p = EpisodeParser.parse("Game of Thrones - Season 1 Episode 2 - The Kingsroad")
        XCTAssertEqual(p?.seriesTitle, "Game of Thrones")
        XCTAssertEqual(p?.season, 1)
        XCTAssertEqual(p?.episode, 2)
    }

    func testSpacedSE() {
        let p = EpisodeParser.parse("Chernobyl - S1 E5")
        XCTAssertEqual(p, .init(seriesTitle: "Chernobyl", season: 1, episode: 5))
    }

    func testNumericShowName() {
        let p = EpisodeParser.parse("24 S03E12")
        XCTAssertEqual(p, .init(seriesTitle: "24", season: 3, episode: 12))
    }

    func testReturnsNilWhenNoMarker() {
        XCTAssertNil(EpisodeParser.parse("Sicario (2015) 1080p"))
    }

    func testHighEpisodeNumbers() {
        let p = EpisodeParser.parse("One Piece S01E1075")
        XCTAssertEqual(p?.episode, 1075)
    }
}
