import XCTest
@testable import Aeria

@MainActor
final class ParentalControlsTests: XCTestCase {

    private func store() -> (ParentalControlsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (ParentalControlsStore(defaults: defaults), defaults)
    }

    func testStartsDisabled() {
        let (s, _) = store()
        XCTAssertFalse(s.isEnabled)
        XCTAssertTrue(s.verify("0000"), "with no PIN set, verify passes")
    }

    func testRejectsMalformedPIN() {
        let (s, _) = store()
        XCTAssertFalse(s.setPIN("12"))
        XCTAssertFalse(s.setPIN("12a4"))
        XCTAssertFalse(s.setPIN("123456"))
        XCTAssertFalse(s.isEnabled)
    }

    func testSetAndVerify() {
        let (s, _) = store()
        XCTAssertTrue(s.setPIN("2468"))
        XCTAssertTrue(s.isEnabled)
        XCTAssertTrue(s.verify("2468"))
        XCTAssertFalse(s.verify("2469"))
    }

    func testDisableRequiresCorrectPIN() {
        let (s, _) = store()
        s.setPIN("1357")
        XCTAssertFalse(s.disable(currentPIN: "0000"))
        XCTAssertTrue(s.isEnabled)
        XCTAssertTrue(s.disable(currentPIN: "1357"))
        XCTAssertFalse(s.isEnabled)
        XCTAssertTrue(s.verify("anything"))
    }

    func testPersistsAcrossInstances() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        ParentalControlsStore(defaults: defaults).setPIN("9999")

        let reloaded = ParentalControlsStore(defaults: defaults)
        XCTAssertTrue(reloaded.isEnabled)
        XCTAssertTrue(reloaded.verify("9999"))
        XCTAssertFalse(reloaded.verify("1111"))
    }

    func testStoredValueIsNotThePlainPIN() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        ParentalControlsStore(defaults: defaults).setPIN("4321")
        let dump = defaults.dictionaryRepresentation().description
        XCTAssertFalse(dump.contains("4321"))
    }
}
