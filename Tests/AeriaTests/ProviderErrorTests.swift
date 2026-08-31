import XCTest
@testable import Aeria

final class ProviderErrorTests: XCTestCase {

    func testMapsURLErrors() {
        XCTAssertEqual(ProviderError.from(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(ProviderError.from(URLError(.timedOut)), .timedOut)
        XCTAssertEqual(ProviderError.from(URLError(.cannotFindHost)), .cannotReachProvider)
        XCTAssertEqual(ProviderError.from(URLError(.cannotConnectToHost)), .cannotReachProvider)
        XCTAssertEqual(ProviderError.from(URLError(.userAuthenticationRequired)), .authenticationFailed)
    }

    func testPassesThroughProviderError() {
        XCTAssertEqual(ProviderError.from(ProviderError.playlistMalformed(reason: "no #EXTM3U")),
                       .playlistMalformed(reason: "no #EXTM3U"))
    }

    func testMapsCancellation() {
        XCTAssertEqual(ProviderError.from(CancellationError()), .cancelled)
    }

    func testEveryErrorHasUserFacingText() {
        let all: [ProviderError] = [
            .offline, .cannotReachProvider, .authenticationFailed, .emptyLibrary, .badResponse,
            .playlistMalformed(reason: "x"), .streamUnavailable, .streamNotSupported(detail: "x"),
            .timedOut, .cancelled, .unknown,
        ]
        for error in all {
            XCTAssertFalse(error.title.isEmpty)
            XCTAssertFalse(error.message.isEmpty)
            XCTAssertFalse(error.message.contains("NSURLErrorDomain"))
        }
    }

    func testRecoveryActionsPresent() {
        XCTAssertTrue(ProviderError.offline.recoveryActions.contains(.retry))
        XCTAssertTrue(ProviderError.authenticationFailed.recoveryActions.contains(.editProvider))
    }
}
