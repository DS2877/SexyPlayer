import XCTest
@testable import SexyPlayer

final class StreamCompatibilityTests: XCTestCase {

    private func verdict(_ s: String) -> StreamCompatibility.Verdict {
        StreamCompatibility.verdict(for: URL(string: s)!)
    }

    func testHLSAndVODAreSupported() {
        XCTAssertEqual(verdict("https://h/live/u/p/1.m3u8"), .supported)
        XCTAssertEqual(verdict("http://h:8080/movie/u/p/55.mp4"), .supported)
        XCTAssertEqual(verdict("https://h/series/u/p/9.mov"), .supported)
        // m3u8 anywhere in the URL still counts as HLS
        XCTAssertEqual(verdict("https://h/stream?type=m3u8&id=5"), .supported)
    }

    func testRawTSIsUnsupported() {
        guard case .unsupported = verdict("http://h:8080/live/u/p/101.ts") else {
            return XCTFail("expected .ts to be unsupported")
        }
    }

    func testContainersUnsupported() {
        for ext in ["mkv", "avi", "flv", "wmv"] {
            guard case .unsupported = verdict("http://h/movie/u/p/1.\(ext)") else {
                return XCTFail("\(ext) should be unsupported")
            }
        }
    }

    func testNonHTTPSchemesUnsupported() {
        guard case .unsupported = verdict("rtmp://h/live/stream") else { return XCTFail() }
        guard case .unsupported = verdict("udp://239.0.0.1:1234") else { return XCTFail() }
    }

    func testUnknownExtensionIsUnknownNotBlocked() {
        XCTAssertEqual(verdict("http://h/live/u/p/1"), .unknown)
        XCTAssertTrue(StreamCompatibility.isProbablyPlayable(URL(string: "http://h/live/u/p/1")!))
    }
}
