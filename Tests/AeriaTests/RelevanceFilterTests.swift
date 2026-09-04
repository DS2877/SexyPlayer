import XCTest
@testable import Aeria

final class RelevanceFilterTests: XCTestCase {

    private func keep(
        _ code: String?, _ name: String = "", _ category: String = "",
        audio: [Language] = [], subs: [Language] = []
    ) -> Bool {
        RelevanceFilter.isRelevant(countryCode: code, name: name, category: category,
                                   audioLanguages: audio, subtitleLanguages: subs)
    }

    func testKeepsNordicEnglishAndEuropeanCountryCodes() {
        for c in ["SE", "NO", "DK", "FI", "IS", "GB", "IE", "US",
                  "DE", "FR", "ES", "IT", "PL", "NL", "GR", "RO", "PT", "HR"] {
            XCTAssertTrue(keep(c), "\(c) should be kept")
        }
    }

    func testDropsNonEuropeanCountryCodes() {
        for c in ["AR", "TR", "IN", "SA", "BR", "RU", "BY", "CN", "NG", "SO", "IR", "PK"] {
            XCTAssertFalse(keep(c), "\(c) should be dropped")
        }
    }

    func testEnglishOrNordicAudioOrSubtitlesKeepsAnythingAnywhere() {
        // "…unless it has english or swedish speak and text."
        XCTAssertTrue(keep("SA", "MBC Persia", "Movies", subs: [.english]))
        XCTAssertTrue(keep("RU", "Kino", "Movies", audio: [.swedish]))
        XCTAssertTrue(keep(nil, "MBC 2", "Arabic Movies", subs: [.swedish]))
        XCTAssertTrue(keep("TR", "Kanal D", "Series", audio: [.english]))
        // Arabic audio only, no English/Nordic anywhere → still dropped.
        XCTAssertFalse(keep("SA", "MBC 1", "News", audio: [.arabic]))
    }

    func testUnknownCountryIsKeptWhenNoForeignMarker() {
        XCTAssertTrue(keep(nil, "beIN Sports 1 HD", "Sports"))
        XCTAssertTrue(keep(nil, "24/7 Friends", "Entertainment"))
        XCTAssertTrue(keep(nil, "Discovery Channel", "Documentary"))
        // European-language markers no longer drop anything — Europe is kept.
        XCTAssertTrue(keep(nil, "TVP Polska", "Polish"))
        XCTAssertTrue(keep(nil, "Das Erste", "German"))
    }

    func testUnknownCountryIsDroppedOnAForeignMarker() {
        XCTAssertFalse(keep(nil, "MBC Masr", "News"))
        XCTAssertFalse(keep(nil, "Zee TV", "Bollywood"))
        XCTAssertFalse(keep(nil, "OSN Yahala", "Arabic Movies"))
        XCTAssertFalse(keep(nil, "Perviy Kanal", "Russian"))
        XCTAssertFalse(keep(nil, "Somali National TV", "Africa"))
    }

    func testWholeWordMatchingAvoidsFalsePositives() {
        // "india" must not match inside "Indiana"
        XCTAssertTrue(keep(nil, "Indiana Jones Marathon", "Movies"))
        // "iran" must not match "Pirates"
        XCTAssertTrue(keep(nil, "Pirates of the Caribbean", "Movies"))
    }

    func testPriorityRanksHomeThenNordicThenEuropeThenRest() {
        let home: Set<String> = ["SE"]
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "SE", home: home), 0)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "NO", home: home), 1)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "GB", home: home), 2)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "DE", home: home), 2)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: nil,  home: home), 2)
        XCTAssertEqual(RelevanceFilter.priority(countryCode: "SA", home: home), 3)
    }

    func testHomeRegionsFromLanguages() {
        XCTAssertEqual(RelevanceFilter.homeRegions(for: []), ["SE"])
        XCTAssertEqual(RelevanceFilter.homeRegions(for: [.swedish]), ["SE"])
        XCTAssertEqual(RelevanceFilter.homeRegions(for: [.norwegian, .danish]), ["NO", "DK"])
    }

    func testChannelCountryCodesByScope() {
        let home: Set<String> = ["SE"]
        XCTAssertEqual(RelevanceFilter.channelCountryCodes(for: .homeCountry, home: home), ["SE"])
        XCTAssertEqual(RelevanceFilter.channelCountryCodes(for: .nordic, home: home),
                       ["SE", "NO", "DK", "FI", "IS"])
        XCTAssertTrue(RelevanceFilter.channelCountryCodes(for: .european, home: home)?.contains("DE") ?? false)
        XCTAssertNil(RelevanceFilter.channelCountryCodes(for: .all, home: home))
    }

    @MainActor
    func testChannelRegionScopeFiltersLiveTV() async {
        let repo = InMemoryCatalogRepository()
        let url = URL(string: "https://x/s")!
        func ch(_ id: String, _ name: String, _ code: String?) -> Channel {
            Channel(id: .init(rawValue: id), name: name, category: "General",
                    countryCode: code, streamURL: url)
        }
        await repo.load(Catalog(channels: [
            ch("se1", "SVT1", "SE"), ch("no1", "NRK1", "NO"),
            ch("de1", "Das Erste", "DE"), ch("gen", "24/7 Nature", nil),
        ]))
        await repo.setHomeRegions(["SE"])

        await repo.setChannelRegionScope(.homeCountry)
        var names = Set(await repo.channels(in: nil, sort: .nameAsc, page: 0, pageSize: 50).map(\.name))
        XCTAssertEqual(names, ["SVT1", "24/7 Nature"])   // home country + generic feeds

        await repo.setChannelRegionScope(.nordic)
        names = Set(await repo.channels(in: nil, sort: .nameAsc, page: 0, pageSize: 50).map(\.name))
        XCTAssertEqual(names, ["SVT1", "NRK1", "24/7 Nature"])

        await repo.setChannelRegionScope(.all)
        let all = await repo.channels(in: nil, sort: .nameAsc, page: 0, pageSize: 50)
        XCTAssertEqual(all.count, 4)
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
