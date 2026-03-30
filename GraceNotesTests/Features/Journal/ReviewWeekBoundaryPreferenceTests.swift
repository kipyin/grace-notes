import XCTest
@testable import GraceNotes

final class ReviewWeekBoundaryPreferenceTests: XCTestCase {
    func test_resolve_unknownRawValue_fallsBackToSundayDefault() {
        let resolved = ReviewWeekBoundaryPreference.resolve(from: "unknown")
        XCTAssertEqual(resolved, .defaultValue)
        XCTAssertEqual(resolved.firstWeekday, 1)
    }

    func test_configuredCalendar_usesPreferenceFirstWeekday() {
        let base = Calendar(identifier: .gregorian)
        let sunday = ReviewWeekBoundaryPreference.sundayStart.configuredCalendar(base: base)
        let monday = ReviewWeekBoundaryPreference.mondayStart.configuredCalendar(base: base)

        XCTAssertEqual(sunday.firstWeekday, 1)
        XCTAssertEqual(monday.firstWeekday, 2)
    }
}
