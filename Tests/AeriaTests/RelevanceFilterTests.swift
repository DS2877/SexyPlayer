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
