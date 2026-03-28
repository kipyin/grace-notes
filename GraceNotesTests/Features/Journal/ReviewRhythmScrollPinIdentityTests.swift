import XCTest
@testable import GraceNotes

final class ReviewRhythmScrollPinIdentityTests: XCTestCase {
    func test_pinIdentity_equalWhenWeekAndDaysMatch() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let day = ReviewDayActivity(date: weekStart, hasReflectiveActivity: true, hasPersistedEntry: true)
        let lhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [day])
        let rhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [day])
        XCTAssertEqual(lhs, rhs)
    }

    func test_pinIdentity_notEqualWhenDayPayloadChanges() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let dayDate = Date(timeIntervalSince1970: 1_700_086_400)
        let rich = ReviewDayActivity(date: dayDate, hasReflectiveActivity: true, hasPersistedEntry: true)
        let sparse = ReviewDayActivity(date: dayDate, hasReflectiveActivity: false, hasPersistedEntry: true)
        let lhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [rich])
        let rhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [sparse])
        XCTAssertNotEqual(lhs, rhs)
    }

    func test_pinIdentity_notEqualWhenReviewWeekChanges() {
        let ws1 = Date(timeIntervalSince1970: 1_700_000_000)
        let ws2 = Date(timeIntervalSince1970: 1_700_086_400)
        let day = ReviewDayActivity(date: ws1, hasReflectiveActivity: true, hasPersistedEntry: true)
        let lhs = ReviewRhythmScrollPinIdentity(weekStart: ws1, days: [day])
        let rhs = ReviewRhythmScrollPinIdentity(weekStart: ws2, days: [day])
        XCTAssertNotEqual(lhs, rhs)
    }
}
