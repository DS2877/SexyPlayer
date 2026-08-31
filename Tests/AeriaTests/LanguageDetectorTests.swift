import XCTest
@testable import Aeria

final class LanguageDetectorTests: XCTestCase {

    func testSweSubTag() {
        let r = LanguageDetector.detect(name: "Hereditary 2018 [SweSub] 1080p")
        XCTAssertEqual(r.subtitles, [.swedish])
        XCTAssertTrue(r.audio.isEmpty)
    }

    func testSpacedSweSub() {
        let r = LanguageDetector.detect(name: "The Conjuring (2013) SWE SUB 1080p")
        XCTAssertEqual(r.subtitles, [.swedish])
    }

    func testLeadingCountryImpliesAudio() {
        let r = LanguageDetector.detect(name: "SE | TV4 HD", groupTitle: "Sweden")
        XCTAssertEqual(r.audio, [.swedish])
    }

    func testBracketedCodeImpliesAudio() {
        let r = LanguageDetector.detect(name: "The Bear S01E01 System [EN] SweSub")
        XCTAssertEqual(r.audio, [.english])
        XCTAssertEqual(r.subtitles, [.swedish])
    }

    func testNordicExpandsSubtitles() {
        let r = LanguageDetector.detect(name: "Movie Night", groupTitle: "Nordic")
        XCTAssertTrue(r.subtitles.contains(.swedish))
        XCTAssertTrue(r.subtitles.contains(.norwegian))
        XCTAssertTrue(r.subtitles.contains(.danish))
    }

    func testGroupTitleNamesAudioLanguage() {
        let r = LanguageDetector.detect(name: "En man som heter Ove", groupTitle: "Movies | Swedish")
        XCTAssertEqual(r.audio, [.swedish])
    }

    func testNoSignalYieldsEmpty() {
        let r = LanguageDetector.detect(name: "Whiplash 2014 1080p", groupTitle: "Drama")
        XCTAssertEqual(r, .empty)
    }
}
