import XCTest
@testable import SexyPlayer

final class QualityDetectorTests: XCTestCase {

    func testDetectsUHD() {
        XCTAssertEqual(QualityDetector.detect(in: "Dune Part Two 2160p UHD"), .uhd)
        XCTAssertEqual(QualityDetector.detect(in: "V Sport Premium 4K"), .uhd)
        XCTAssertEqual(QualityDetector.detect(in: "Movie [Ultra HD]"), .uhd)
    }

    func testDetectsFHD() {
        XCTAssertEqual(QualityDetector.detect(in: "SVT1 1080p"), .fhd)
        XCTAssertEqual(QualityDetector.detect(in: "TV4 FHD"), .fhd)
        XCTAssertEqual(QualityDetector.detect(in: "Kanal 5 Full HD"), .fhd)
    }

    func testDetectsHD() {
        XCTAssertEqual(QualityDetector.detect(in: "TV4 HD"), .hd)
        XCTAssertEqual(QualityDetector.detect(in: "BBC One 720p"), .hd)
    }

    func testDetectsSD() {
        XCTAssertEqual(QualityDetector.detect(in: "TV6 SD"), .sd)
        XCTAssertEqual(QualityDetector.detect(in: "Channel 480p"), .sd)
    }

    func testUnknownWhenAbsent() {
        XCTAssertEqual(QualityDetector.detect(in: "National Geographic"), .unknown)
    }

    func testHDInsideWordDoesNotFalseMatch() {
        // "childhood" contains "hd"? no. "AHD" style camera term should not be HD.
        XCTAssertEqual(QualityDetector.detect(in: "Storhospital Drama"), .unknown)
    }

    func testPicksHighestAcrossCandidates() {
        XCTAssertEqual(QualityDetector.detect(in: ["TV4 HD", "TV4 group 4K"]), .uhd)
    }

    func testComparableOrdering() {
        XCTAssertLessThan(VideoQuality.sd, VideoQuality.hd)
        XCTAssertLessThan(VideoQuality.hd, VideoQuality.fhd)
        XCTAssertLessThan(VideoQuality.fhd, VideoQuality.uhd)
    }
}
