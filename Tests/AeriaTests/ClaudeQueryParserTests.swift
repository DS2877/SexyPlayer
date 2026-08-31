import XCTest
@testable import Aeria

final class ClaudeQueryParserTests: XCTestCase {

    private let vocab = SearchVocabulary(
        genres: [.horror, .comedy, .sciFi],
        audioLanguages: [.english, .swedish],
        subtitleLanguages: [.swedish]
    )

    func testMapsCleanJSON() throws {
        let text = #"{"kinds":["movie"],"genres":["horror"],"subtitleLanguages":["sv"],"minYear":2015,"minQuality":"uhd","freeText":"haunted house"}"#
        let intent = try ClaudeQueryParser.intent(fromModelText: text, vocabulary: vocab)
        XCTAssertEqual(intent.kinds, [.movie])
        XCTAssertEqual(intent.genres, [.horror])
        XCTAssertEqual(intent.subtitleLanguages, [.swedish])
        XCTAssertEqual(intent.minYear, 2015)
        XCTAssertEqual(intent.minQuality, .uhd)
        XCTAssertEqual(intent.freeText, "haunted house")
    }

    func testStripsCodeFencesAndProse() throws {
        let text = "Here you go:\n```json\n{\"genres\": [\"comedy\"]}\n```"
        let intent = try ClaudeQueryParser.intent(fromModelText: text, vocabulary: vocab)
        XCTAssertEqual(intent.genres, [.comedy])
    }

    func testDropsTokensOutsideVocabulary() throws {
        let text = #"{"genres":["western"],"audioLanguages":["de"]}"#
        let intent = try ClaudeQueryParser.intent(fromModelText: text, vocabulary: vocab)
        XCTAssertTrue(intent.genres.isEmpty, "western isn't in the library vocabulary")
        XCTAssertTrue(intent.audioLanguages.isEmpty, "German isn't in the library vocabulary")
    }

    func testThrowsOnGarbage() {
        XCTAssertThrowsError(try ClaudeQueryParser.intent(fromModelText: "no json here", vocabulary: vocab))
    }

    func testSystemPromptListsVocabulary() {
        let prompt = ClaudeQueryParser.systemPrompt(vocab)
        XCTAssertTrue(prompt.contains("horror"))
        XCTAssertTrue(prompt.contains("sv"))
        XCTAssertFalse(prompt.contains("credentials are"), "must not leak anything but vocab")
    }
}
