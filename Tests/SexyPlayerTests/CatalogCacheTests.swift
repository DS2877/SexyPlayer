import XCTest
@testable import SexyPlayer

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

    func testSaveAndLoad() async throws {
        let cache = CatalogCache()
        let providerID = "test-\(UUID().uuidString)"
        defer { Task { await cache.clear(providerID: providerID) } }

        let catalog = Normalizer().normalize(MockCatalogData.rawCatalog())
        await cache.save(catalog, providerID: providerID)

        let entry = await cache.load(providerID: providerID)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.catalog.movies.count, catalog.movies.count)
        XCTAssertLessThan(entry?.age ?? .infinity, 5)
    }

    func testMissingProviderReturnsNil() async {
        let cache = CatalogCache()
        let entry = await cache.load(providerID: "definitely-not-saved-\(UUID().uuidString)")
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
        let entry = await cache.load(providerID: providerID)
        XCTAssertEqual(entry?.catalog.epg.map(\.title), ["NowIsh"])
    }
}
