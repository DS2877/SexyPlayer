import XCTest
@testable import Aeria

final class XMLTVParserTests: XCTestCase {

    private let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <tv>
      <channel id="svt1.se"><display-name>SVT1</display-name></channel>
      <programme start="20260115180000 +0000" stop="20260115190000 +0000" channel="svt1.se">
        <title>Rapport</title>
        <desc>Evening news.</desc>
        <category>News</category>
      </programme>
      <programme start="20260115190000 +0100" stop="20260115200000 +0100" channel="svt1.se">
        <title>Aktuellt</title>
        <sub-title>Special</sub-title>
      </programme>
      <programme start="bad" stop="also bad" channel="x"><title>Broken</title></programme>
    </tv>
    """

    func testParsesProgrammes() throws {
        let events = try XMLTVParser.parse(Data(xml.utf8))
        XCTAssertEqual(events.count, 2)   // the broken one is dropped

        let first = events[0]
        XCTAssertEqual(first.channelID, "svt1.se")
        XCTAssertEqual(first.title, "Rapport")
        XCTAssertEqual(first.description, "Evening news.")
        XCTAssertEqual(first.category, "News")
    }

    func testTimezoneHandling() throws {
        let events = try XMLTVParser.parse(Data(xml.utf8))
        // 18:00 +0000 and 19:00 +0100 are the same instant.
        XCTAssertEqual(events[0].start.timeIntervalSince1970,
                       events[1].start.timeIntervalSince1970, accuracy: 1)
    }

    func testInvalidXMLThrows() {
        XCTAssertThrowsError(try XMLTVParser.parse(Data("<tv><programme".utf8)))
    }

    func testGzipDetected() {
        var gz = Data([0x1f, 0x8b, 0x08, 0x00])
        gz.append(Data(repeating: 0, count: 20))
        XCTAssertThrowsError(try XMLTVParser.parse(gz))
    }
}
