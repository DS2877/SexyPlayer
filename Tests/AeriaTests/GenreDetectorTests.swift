import XCTest
@testable import Aeria

final class GenreDetectorTests: XCTestCase {

    func testFromExplicitGenreText() {
        let g = GenreDetector.detect(from: ["Action, Crime, Thriller"])
        XCTAssertTrue(g.contains(.action))
        XCTAssertTrue(g.contains(.crime))
        XCTAssertTrue(g.contains(.thriller))
    }

    func testFromGroupTitle() {
        XCTAssertEqual(GenreDetector.detect(from: ["Movies | Horror"]), [.horror])
    }

    func testAnimeMapsToAnimation() {
        XCTAssertTrue(GenreDetector.detect(from: [nil, "Anime Series"]).contains(.animation))
    }

    func testEmptyWhenNoSignal() {
        XCTAssertTrue(GenreDetector.detect(from: [nil, nil]).isEmpty)
        XCTAssertTrue(GenreDetector.detect(from: ["Channel 4"]).isEmpty)
    }
}
