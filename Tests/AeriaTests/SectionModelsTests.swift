import XCTest
@testable import Aeria

/// `SectionModels` is what makes switching sections instant, so its two
/// invariants matter: a section must not reload when nothing changed, and it
/// *must* reload when the catalog underneath it did.
@MainActor
final class SectionModelsTests: XCTestCase {

    func testUnvisitedSectionNeedsLoad() {
        let models = SectionModels()
        XCTAssertTrue(models.needsLoad(.home, revision: 0))
        XCTAssertTrue(models.needsLoad(.movies, revision: 0))
    }

    func testLoadedSectionDoesNotReloadAtTheSameRevision() {
        let models = SectionModels()
        models.markLoaded(.movies, revision: 7)
        XCTAssertFalse(models.needsLoad(.movies, revision: 7))
        // A different section is unaffected.
        XCTAssertTrue(models.needsLoad(.series, revision: 7))
    }

    /// The case that made this necessary: visit a screen mid-import, come back
    /// after it finished, and you must not still be looking at the partial
    /// library the first visit saw.
    func testNewerCatalogRevisionForcesAReload() {
        let models = SectionModels()
        models.markLoaded(.liveTV, revision: 3)
        XCTAssertFalse(models.needsLoad(.liveTV, revision: 3))
        XCTAssertTrue(models.needsLoad(.liveTV, revision: 4))
    }

    /// A provider switch discards every model. The section views hold a `@State`
    /// handle on theirs, so the generation has to move or they'd keep rendering
    /// the previous library's data.
    func testResetBumpsTheGeneration() {
        let models = SectionModels()
        let start = models.generation

        // Nothing created yet — reset is a no-op, so views don't churn.
        models.reset()
        XCTAssertEqual(models.generation, start)

        models.markLoaded(.home, revision: 1)
        models.reset()
        XCTAssertEqual(models.generation, start + 1)
        XCTAssertTrue(models.needsLoad(.home, revision: 1), "reset must clear load state too")
    }
}
