import XCTest
@testable import SexyPlayer

final class LenientCodingTests: XCTestCase {

    private struct Sample: Decodable {
        @LenientInt var count: Int?
        @LenientString var label: String?
    }

    func testIntFromVariousShapes() throws {
        func count(_ json: String) throws -> Int? {
            try JSONDecoder().decode(Sample.self, from: Data(json.utf8)).count
        }
        XCTAssertEqual(try count(#"{"count": 5}"#), 5)
        XCTAssertEqual(try count(#"{"count": "5"}"#), 5)
        XCTAssertEqual(try count(#"{"count": 5.0}"#), 5)
        XCTAssertEqual(try count(#"{"count": " 7 "}"#), 7)
        XCTAssertNil(try count(#"{"count": null}"#))
        XCTAssertNil(try count(#"{"count": "abc"}"#))
        XCTAssertNil(try count(#"{}"#))
    }

    func testStringFromVariousShapes() throws {
        func label(_ json: String) throws -> String? {
            try JSONDecoder().decode(Sample.self, from: Data(json.utf8)).label
        }
        XCTAssertEqual(try label(#"{"label": "hi"}"#), "hi")
        XCTAssertEqual(try label(#"{"label": 42}"#), "42")
        XCTAssertNil(try label(#"{"label": ""}"#))
        XCTAssertNil(try label(#"{"label": null}"#))
        XCTAssertNil(try label(#"{}"#))
    }
}
