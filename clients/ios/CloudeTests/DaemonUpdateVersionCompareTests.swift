import XCTest

@testable import Cloude

final class DaemonUpdateVersionCompareTests: XCTestCase {
    func testMissingPartsAreTreatedAsZero() {
        XCTAssertFalse(DaemonUpdateVersionCompare.isOlder("2026.05.05", than: "2026.05.05.0"))
        XCTAssertTrue(DaemonUpdateVersionCompare.isOlder("2026.05.04.9", than: "2026.05.05"))
    }

    func testMalformedPartsAreTreatedAsZero() {
        XCTAssertTrue(DaemonUpdateVersionCompare.isOlder("2026.05.beta", than: "2026.05.1"))
        XCTAssertFalse(DaemonUpdateVersionCompare.isOlder("2026.05.2", than: "2026.05.beta"))
    }

    func testDaemonUpdateStaleRulesIgnoreLocalDevelopmentVersions() {
        XCTAssertFalse(DaemonUpdate.isStale(version: nil))
        XCTAssertFalse(DaemonUpdate.isStale(version: "dev"))
        XCTAssertTrue(DaemonUpdate.isStale(version: "2026.05.05"))
        XCTAssertFalse(DaemonUpdate.isStale(version: DaemonUpdate.minVersion))
    }
}
