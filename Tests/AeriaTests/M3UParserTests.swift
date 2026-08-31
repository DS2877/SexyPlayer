import XCTest
@testable import Aeria

final class M3UParserTests: XCTestCase {

    private let sample = """
    #EXTM3U
    #EXTINF:-1 tvg-id="svt1.se" tvg-name="SVT1" tvg-logo="http://logo/svt1.png" group-title="Sweden",SE | SVT1 HD
    http://host:8080/live/user/pass/101.m3u8
    #EXTINF:-1 tvg-id="" tvg-logo="http://logo/tv4.png" group-title="Sweden | Movies",Sicario (2015)
    http://host:8080/movie/user/pass/555.mp4
    #EXTINF:-1 group-title="Series | Drama",The Last of Us S01E01
    http://host:8080/series/user/pass/900.mp4
    #EXTINF:-1 group-title="News",CNN International
    http://host:8080/live/user/pass/200.ts
    """

    func testParsesHeaderRequirement() {
        XCTAssertThrowsError(try M3UParser.parse(text: "not a playlist", providerID: "p"))
    }

    func testClassifiesEntries() throws {
        let catalog = try M3UParser.parse(text: sample, providerID: "p")
        XCTAssertEqual(catalog.channels.count, 2)          // SVT1, CNN
        XCTAssertEqual(catalog.vod.count, 1)               // Sicario
        XCTAssertEqual(catalog.seriesEpisodes.count, 1)    // TLOU S01E01
    }

    func testChannelAttributesExtracted() throws {
        let catalog = try M3UParser.parse(text: sample, providerID: "p")
        let svt1 = try XCTUnwrap(catalog.channels.first { $0.displayName.contains("SVT1") })
        XCTAssertEqual(svt1.tvgID, "svt1.se")
        XCTAssertEqual(svt1.groupTitle, "Sweden")
        XCTAssertEqual(svt1.streamURL, "http://host:8080/live/user/pass/101.m3u8")
        XCTAssertEqual(svt1.logo, "http://logo/svt1.png")
    }

    func testExtInfParsing() {
        let (name, attrs) = M3UParser.parseExtInf(#"#EXTINF:-1 tvg-id="a.b" group-title="X, Y",Channel, With Comma"#)
        XCTAssertEqual(name, "Channel, With Comma")
        XCTAssertEqual(attrs["tvg-id"], "a.b")
        XCTAssertEqual(attrs["group-title"], "X, Y")
    }

    func testEmptyPlaylistThrows() {
        XCTAssertThrowsError(try M3UParser.parse(text: "#EXTM3U\n", providerID: "p"))
    }

    func testURLShapeClassificationWithoutGroups() throws {
        let text = """
        #EXTM3U
        #EXTINF:-1,Movie Without Group
        http://h/movie/u/p/1.mkv
        #EXTINF:-1,Channel Without Group
        http://h/live/u/p/2.m3u8
        """
        let catalog = try M3UParser.parse(text: text, providerID: "p")
        XCTAssertEqual(catalog.vod.count, 1)
        XCTAssertEqual(catalog.channels.count, 1)
    }
}
