import XCTest
@testable import Aeria

final class RelevanceFilterTests: XCTestCase {

    private func keep(_ code: String?, _ name: String = "", _ category: String = "") -> Bool {
        RelevanceFilter.isRelevant(countryCode: code, name: name, category: category)
    }

    func testKeepsNordicAndEnglishCountryCodes() {
        for c in ["SE", "NO", "DK", "FI", "IS", "GB", "IE", "US"] {
            XCTAssertTrue(keep(c), "\(c) should be kept")
        }
    }

    func testDropsForeignCountryCodes() {
        for c in ["AR", "TR", "PL", "RO", "GR", "IN", "SA", "BR", "RU", "DE", "FR", "ES", "IT"] {
            XCTAssertFalse(keep(c), "\(c) should be dropped")
        }
    }

    func testUnknownCountryIsKeptWhenNoForeignMarker() {
        XCTAssertTrue(keep(nil, "beIN Sports 1 HD", "Sports"))
        XCTAssertTrue(keep(nil, "24/7 Friends", "Entertainment"))
        XCTAssertTrue(keep(nil, "Discovery Channel", "Documentary"))
    }

    func testUnknownCountryIsDroppedOnAForeignMarker() {
        XCTAssertFalse(keep(nil, "MBC Masr", "News"))
        XCTAssertFalse(keep(nil, "Zee TV", "Bollywood"))
        XCTAssertFalse(keep(nil, "TVP Polska", "Polish"))
        XCTAssertFalse(keep(nil, "OSN Yahala", "Arabic Movies"))
    }

    func testWholeWordMatchingAvoidsFalsePositives() {
        // "india" must not match inside "Indiana"
        XCTAssertTrue(keep(nil, "Indiana Jones Marathon", "Movies"))
        // "iran" must not match "Tehrangeles"… nor "irate"
        XCTAssertTrue(keep(nil, "Pirates of the Caribbean", "Movies"))
    }

    func testPriorityRanksHomeThenNordicThenEnglish() {
        let home: Set<String> = ["SE"]
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "SE", home: home), 0)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "NO", home: home), 1)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "GB", home: home), 2)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: nil,  home: home), 2)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "DE", home: home), 3)
    }

    func testHomeRegionsFromLanguages() {
        XCTAssertEqual(RelevanceFilter.homeRegions(for: []), ["SE"])
        XCTAssertEqual(RelevanceFilter.homeRegions(for: [.swedish]), ["SE"])
        XCTAssertEqual(RelevanceFilter.homeRegions(for: [.norwegian, .danish]), ["NO", "DK"])
    }

    @MainActor
    func testChannelSortPutsHomeCountryAndRegularsFirst() async {
        let repo = InMemoryCatalogRepository()
        let url = URL(string: "https://x/s")!
        func ch(_ id: String, _ name: String, _ code: String?, num: Int) -> Channel {
            Channel(id: .init(rawValue: id), name: name, category: "General",
                    countryCode: code, streamURL: url, sortIndex: num)
        }
        await repo.load(Catalog(channels: [
            ch("gb1", "BBC One", "GB", num: 1),
            ch("se2", "SVT2", "SE", num: 2),
            ch("no1", "NRK1", "NO", num: 1),
            ch("se1", "SVT1", "SE", num: 1),
        ]))
        await repo.setHomeRegions(["SE"])

        var order = await repo.channels(in: nil, sort: .number, page: 0, pageSize: 10).map(\.name)
        XCTAssertEqual(order, ["SVT1", "SVT2", "NRK1", "BBC One"])

        // Watching BBC One floats it to the very top.
        await repo.setRecentChannels([.init(rawValue: "gb1")])
        order = await repo.channels(in: nil, sort: .number, page: 0, pageSize: 10).map(\.name)
        XCTAssertEqual(order.first, "BBC One")
    }

    @MainActor
    func testRepositoryAppliesTheFilter() async {
        let repo = InMemoryCatalogRepository()
        let url = URL(string: "https://x/s")!
        await repo.load(Catalog(channels: [
            Channel(id: .init(rawValue: "c1"), name: "SVT1", category: "General",
                    countryCode: "SE", streamURL: url),
            Channel(id: .init(rawValue: "c2"), name: "MBC 1", category: "General",
                    countryCode: "SA", streamURL: url),
        ]))

        var all = await repo.channels(in: nil, sort: .number, page: 0, pageSize: 50)
        XCTAssertEqual(all.map(\.name), ["SVT1", "MBC 1"])

        await repo.setRegionLimit(true)
        all = await repo.channels(in: nil, sort: .number, page: 0, pageSize: 50)
        XCTAssertEqual(all.map(\.name), ["SVT1"])
    }
}
