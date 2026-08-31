import XCTest
@testable import Aeria

final class CatalogCacheTests: XCTestCase {

    func testCatalogRoundTripsThroughJSON() throws {
        let original = Normalizer().normalize(MockCatalogData.rawCatalog())
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Catalog.self, from: data)

        XCTAssertEqual(restored.movies.map(\.title), original.movies.map(\.title))
        XCTAssertEqual(restored.channels.map(\.id), original.channels.map(\.id))
        XCTAssertEqual(restored.series.flatMap { $0.seasons.flatMap(\.episodes) }.map(\.id),
                       original.series.flatMap { $0.seasons.flatMap(\.episodes) }.map(\.id))
    }

    func testSaveAndLoadThreeFileSplit() async throws {
        let cache = CatalogCache()
        let providerID = "test-\(UUID().uuidString)"
        defer { Task { await cache.clear(providerID: providerID) } }

        let catalog = Normalizer().normalize(MockCatalogData.rawCatalog())
        await cache.save(catalog, providerID: providerID)

        let channels = await cache.loadChannels(providerID: providerID)
        XCTAssertEqual(channels?.channels.count, catalog.channels.count)
        XCTAssertLessThan(channels?.age ?? .infinity, 5)

        let vod = await cache.loadVOD(providerID: providerID)
        XCTAssertEqual(vod.movies.count, catalog.movies.count)
        XCTAssertEqual(vod.series.count, catalog.series.count)
    }

    func testMissingProviderReturnsNil() async {
        let cache = CatalogCache()
        let entry = await cache.loadChannels(providerID: "definitely-not-saved-\(UUID().uuidString)")
        XCTAssertNil(entry)
    }

    func testEPGTrimmedToWindowOnSave() async {
        let cache = CatalogCache()
        let providerID = "epgtest-\(UUID().uuidString)"
        defer { Task { await cache.clear(providerID: providerID) } }

        let now = Date()
        let catalog = Catalog(epg: [
            EPGEvent(channelEPGID: "c", title: "Ancient",
                     start: now.addingTimeInterval(-40 * 24 * 3600),
                     stop: now.addingTimeInterval(-40 * 24 * 3600 + 3600)),
            EPGEvent(channelEPGID: "c", title: "NowIsh",
                     start: now.addingTimeInterval(-600), stop: now.addingTimeInterval(3000)),
        ])
        await cache.save(catalog, providerID: providerID)
        let events = await cache.loadEPG(providerID: providerID)
        XCTAssertEqual(events.map(\.title), ["NowIsh"])
    }
}
