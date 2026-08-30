import XCTest
@testable import SexyPlayer

final class ChannelLineupTests: XCTestCase {

    private func channel(_ key: String) -> Channel {
        Channel(id: CatalogID(providerID: "p", kind: .liveChannel, providerItemKey: key),
                name: key.uppercased(), category: "General",
                streamURL: URL(string: "https://example.com/\(key).m3u8")!)
    }

    func testNextAndPreviousWrapAround() {
        let a = channel("a"), b = channel("b"), c = channel("c")
        let lineup = ChannelLineup(channels: [a, b, c], currentID: b.id)

        XCTAssertEqual(lineup.channel(offset: 1)?.id, c.id)
        XCTAssertEqual(lineup.channel(offset: -1)?.id, a.id)

        let atEnd = ChannelLineup(channels: [a, b, c], currentID: c.id)
        XCTAssertEqual(atEnd.channel(offset: 1)?.id, a.id, "wraps to first")

        let atStart = ChannelLineup(channels: [a, b, c], currentID: a.id)
        XCTAssertEqual(atStart.channel(offset: -1)?.id, c.id, "wraps to last")
    }

    func testMovedUpdatesCurrent() {
        let a = channel("a"), b = channel("b")
        let lineup = ChannelLineup(channels: [a, b], currentID: a.id).moved(to: b.id)
        XCTAssertEqual(lineup.currentID, b.id)
        XCTAssertEqual(lineup.channel(offset: 1)?.id, a.id)
    }

    func testEmptyAndUnknownCurrentAreSafe() {
        XCTAssertNil(ChannelLineup(channels: [], currentID: channel("a").id).channel(offset: 1))
        let lineup = ChannelLineup(channels: [channel("a")], currentID: channel("z").id)
        XCTAssertNil(lineup.channel(offset: 1), "current not in list -> nil, no crash")
    }
}
