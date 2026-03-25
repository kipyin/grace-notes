import XCTest
@testable import GraceNotes

final class MarketingVersionTests: XCTestCase {
    func test_compare_ordersSemverSegments() {
        XCTAssertEqual(MarketingVersion.compare("0.5.0", "0.5.1"), .orderedAscending)
        XCTAssertEqual(MarketingVersion.compare("0.5.1", "0.5.1"), .orderedSame)
        XCTAssertEqual(MarketingVersion.compare("0.5.2", "0.5.1"), .orderedDescending)
        XCTAssertEqual(MarketingVersion.compare("0.4.9", "0.5.0"), .orderedAscending)
        XCTAssertEqual(MarketingVersion.compare("1.0", "0.9.9"), .orderedDescending)
    }

    func test_orientationReleaseGate_priorLaunchBeforeAnchor() {
        XCTAssertTrue(OrientationReleaseGate.isPriorLaunchBeforeRelease(marketing: "0.4.0", storedBundle: nil))
        XCTAssertTrue(OrientationReleaseGate.isPriorLaunchBeforeRelease(marketing: "0.5.0", storedBundle: nil))
        XCTAssertTrue(OrientationReleaseGate.isPriorLaunchBeforeRelease(marketing: "0.5.0", storedBundle: 3))
        XCTAssertFalse(OrientationReleaseGate.isPriorLaunchBeforeRelease(marketing: "0.5.0", storedBundle: 7))
        XCTAssertFalse(OrientationReleaseGate.isPriorLaunchBeforeRelease(marketing: "0.5.1", storedBundle: nil))
    }

    func test_orientationReleaseGate_currentAtOrAfterAnchor() {
        XCTAssertTrue(OrientationReleaseGate.isCurrentLaunchAtOrAfterRelease(marketing: "0.5.0", bundle: 7))
        XCTAssertTrue(OrientationReleaseGate.isCurrentLaunchAtOrAfterRelease(marketing: "0.6.0", bundle: 1))
        XCTAssertFalse(OrientationReleaseGate.isCurrentLaunchAtOrAfterRelease(marketing: "0.5.0", bundle: 6))
        XCTAssertFalse(OrientationReleaseGate.isCurrentLaunchAtOrAfterRelease(marketing: "0.4.0", bundle: 99))
    }
}
