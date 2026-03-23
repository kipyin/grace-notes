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
}
