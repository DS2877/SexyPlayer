import XCTest
@testable import Aeria

final class TitleNormalizerTests: XCTestCase {

    func testChannelNameStripsCountryPrefixQualityAndTags() {
        XCTAssertEqual(TitleNormalizer.channelName("SE | TV4 HD [1080p]"), "TV4")
        XCTAssertEqual(TitleNormalizer.channelName("TV4.HD Sweden"), "TV4")
        XCTAssertEqual(TitleNormalizer.channelName("TV4 HD [SE]"), "TV4")
        XCTAssertEqual(TitleNormalizer.channelName("SE: TV4 FHD"), "TV4")
    }

    func testChannelNameKeepsMeaningfulDigits() {
        XCTAssertEqual(TitleNormalizer.channelName("Kanal 5 [SE] 1080P"), "Kanal 5")
        XCTAssertEqual(TitleNormalizer.channelName("UK | BBC One HD"), "BBC One")
    }

    func testChannelNameNeverReturnsEmpty() {
        XCTAssertEqual(TitleNormalizer.channelName("HD"), "HD")
        XCTAssertEqual(TitleNormalizer.channelName("   "), "")
    }

    func testMovieTitleAndYear() {
        let a = TitleNormalizer.movieTitle("VOD: Sicario (2015) 1080p")
        XCTAssertEqual(a.title, "Sicario")
        XCTAssertEqual(a.year, 2015)

        let b = TitleNormalizer.movieTitle("Parasite.2019.1080p.MULTI")
        XCTAssertEqual(b.title, "Parasite")
        XCTAssertEqual(b.year, 2019)

        let c = TitleNormalizer.movieTitle("The Grand Budapest Hotel (2014) 1080p")
        XCTAssertEqual(c.title, "The Grand Budapest Hotel")
        XCTAssertEqual(c.year, 2014)
    }

    func testMovieTitleWithoutYear() {
        let r = TitleNormalizer.movieTitle("Nobody 1080p")
        XCTAssertEqual(r.title, "Nobody")
        XCTAssertNil(r.year)
    }

    func testExtractYearRejectsImplausible() {
        XCTAssertNil(TitleNormalizer.extractYear("Room 1408"))
        XCTAssertNil(TitleNormalizer.extractYear("2525 A Space Odyssey"))
        XCTAssertEqual(TitleNormalizer.extractYear("Alien (1979)"), 1979)
    }

    func testEpisodeRawNameKeepsMarker() {
        let r = TitleNormalizer.episodeRawName("The Bear S01E02 Hands SweSub [MULTI]")
        XCTAssertTrue(r.contains("S01E02"))
        XCTAssertFalse(r.lowercased().contains("multi"))
    }
}
