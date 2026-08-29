import XCTest
@testable import SexyPlayer

final class EPGTests: XCTestCase {

    private func event(startOffset: TimeInterval, duration: TimeInterval, now: Date) -> EPGEvent {
        EPGEvent(
            channelEPGID: "c1",
            title: "Show",
            start: now.addingTimeInterval(startOffset),
            stop: now.addingTimeInterval(startOffset + duration)
        )
    }

    func testIsLive() {
        let now = Date()
        let live = event(startOffset: -600, duration: 3600, now: now)
        let past = event(startOffset: -7200, duration: 3600, now: now)
        let future = event(startOffset: 600, duration: 3600, now: now)
        XCTAssertTrue(live.isLive(at: now))
        XCTAssertFalse(past.isLive(at: now))
        XCTAssertFalse(future.isLive(at: now))
    }

    func testProgressClamped() {
        let now = Date()
        let e = event(startOffset: -1800, duration: 3600, now: now)   // half way
        XCTAssertEqual(e.progress(at: now), 0.5, accuracy: 0.01)
        XCTAssertEqual(e.progress(at: now.addingTimeInterval(-99999)), 0.0)
        XCTAssertEqual(e.progress(at: now.addingTimeInterval(99999)), 1.0)
    }

    func testZeroDurationDoesNotCrash() {
        let now = Date()
        let e = event(startOffset: 0, duration: 0, now: now)
        XCTAssertEqual(e.progress(at: now), 0)
    }

    func testCatalogNowPlayingAndWindow() {
        let now = Date()
        let catalog = Catalog(epg: [
            EPGEvent(channelEPGID: "c1", title: "Morning", start: now.addingTimeInterval(-7200), stop: now.addingTimeInterval(-3600)),
            EPGEvent(channelEPGID: "c1", title: "Now",     start: now.addingTimeInterval(-600),  stop: now.addingTimeInterval(3000)),
            EPGEvent(channelEPGID: "c1", title: "Later",   start: now.addingTimeInterval(3000),  stop: now.addingTimeInterval(6600)),
            EPGEvent(channelEPGID: "c2", title: "Other",   start: now.addingTimeInterval(-600),  stop: now.addingTimeInterval(3000)),
        ])
        XCTAssertEqual(catalog.nowPlaying(forEPGID: "c1", at: now)?.title, "Now")

        let window = DateInterval(start: now, end: now.addingTimeInterval(7200))
        let events = catalog.events(forEPGID: "c1", in: window)
        XCTAssertEqual(events.map(\.title), ["Now", "Later"])
    }

    func testWatchProgressResumeLogic() {
        let id = CatalogID(rawValue: "movie:1")
        let early = WatchProgress(itemID: id, kind: .movie, positionSeconds: 10, durationSeconds: 6000)
        let mid = WatchProgress(itemID: id, kind: .movie, positionSeconds: 3000, durationSeconds: 6000)
        let done = WatchProgress(itemID: id, kind: .movie, positionSeconds: 5900, durationSeconds: 6000)
        XCTAssertFalse(early.isResumable)   // < 30s in
        XCTAssertTrue(mid.isResumable)
        XCTAssertFalse(done.isResumable)
        XCTAssertTrue(done.isFinished)
    }
}
