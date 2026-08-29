import XCTest
@testable import SexyPlayer

/// A stand-in for the future remote (Claude) parser. Unit tests never touch a
/// live model.
private struct StubRemoteParser: AIQueryParser {
    let intent: SearchIntent
    var recordedQueries: RecordingBox = .init()

    func parse(_ query: String, vocabulary: SearchVocabulary) async throws -> SearchIntent {
        recordedQueries.append(query)
        return intent
    }

    final class RecordingBox: @unchecked Sendable {
        private(set) var values: [String] = []
        func append(_ v: String) { values.append(v) }
    }
}

private struct FailingRemoteParser: AIQueryParser {
    func parse(_ query: String, vocabulary: SearchVocabulary) async throws -> SearchIntent {
        throw AIQueryParserError.providerUnavailable
    }
}

final class AIServiceTests: XCTestCase {

    func testOnDeviceOnlyNeverCallsRemote() async {
        let stub = StubRemoteParser(intent: SearchIntent(genres: [.fantasy]))
        let service = AIService(remote: stub, mode: .onDeviceOnly)
        let intent = await service.intent(for: "something like game of thrones", vocabulary: .init())
        XCTAssertEqual(stub.recordedQueries.values, [])
        XCTAssertEqual(intent.freeText, "game of thrones")
    }

    func testAssistedEscalatesOnlyWhenUnresolved() async {
        let stub = StubRemoteParser(intent: SearchIntent(kinds: [.series], genres: [.fantasy], freeText: "game of thrones"))
        let service = AIService(remote: stub, mode: .assisted)

        // Resolvable locally → no remote call.
        _ = await service.intent(for: "horror movies with swedish subtitles", vocabulary: .init())
        XCTAssertEqual(stub.recordedQueries.values, [])

        // Fuzzy → escalates.
        let intent = await service.intent(for: "something like game of thrones", vocabulary: .init())
        XCTAssertEqual(stub.recordedQueries.values, ["something like game of thrones"])
        XCTAssertTrue(intent.genres.contains(.fantasy))
    }

    func testAssistedFallsBackWhenRemoteFails() async {
        let service = AIService(remote: FailingRemoteParser(), mode: .assisted)
        let intent = await service.intent(for: "something like the wire", vocabulary: .init())
        XCTAssertEqual(intent.freeText, "the wire")   // on-device result preserved
    }

    func testEmptyQuery() async {
        let service = AIService(mode: .onDeviceOnly)
        let intent = await service.intent(for: "   ", vocabulary: .init())
        XCTAssertEqual(intent, .empty)
    }
}
