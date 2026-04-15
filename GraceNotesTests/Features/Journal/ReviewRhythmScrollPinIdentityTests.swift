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

    func test_pinIdentity_equalWhenOnlyPerDayPayloadFlagsChange() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let dayDate = Date(timeIntervalSince1970: 1_700_086_400)
        let rich = ReviewDayActivity(date: dayDate, hasReflectiveActivity: true, hasPersistedEntry: true)
        let sparse = ReviewDayActivity(date: dayDate, hasReflectiveActivity: false, hasPersistedEntry: true)
        let lhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [rich])
        let rhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [sparse])
        XCTAssertEqual(lhs, rhs)
    }

    func test_pinIdentity_equalWhenOnlyStrongestCompletionLevelChanges() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let dayDate = Date(timeIntervalSince1970: 1_700_086_400)
        let lhsDay = ReviewDayActivity(
            date: dayDate,
            hasReflectiveActivity: true,
            strongestCompletionLevel: .soil,
            hasPersistedEntry: true
        )
        let rhsDay = ReviewDayActivity(
            date: dayDate,
            hasReflectiveActivity: true,
            strongestCompletionLevel: .leaf,
            hasPersistedEntry: true
        )
        let lhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [lhsDay])
        let rhs = ReviewRhythmScrollPinIdentity(weekStart: weekStart, days: [rhsDay])
        XCTAssertEqual(lhs, rhs)
    }

    func test_pinIdentity_notEqualWhenReviewWeekChanges() {
        let ws1 = Date(timeIntervalSince1970: 1_700_000_000)
        let ws2 = Date(timeIntervalSince1970: 1_700_086_400)
        let day = ReviewDayActivity(date: ws1, hasReflectiveActivity: true, hasPersistedEntry: true)
        let lhs = ReviewRhythmScrollPinIdentity(weekStart: ws1, days: [day])
        let rhs = ReviewRhythmScrollPinIdentity(weekStart: ws2, days: [day])
        XCTAssertNotEqual(lhs, rhs)
    }

    func test_pinIdentity_notEqualWhenDayColumnDatesDiffer() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let earlierDay = Date(timeIntervalSince1970: 1_700_086_400)
        let laterDay = Date(timeIntervalSince1970: 1_700_172_800)
        let lhs = ReviewRhythmScrollPinIdentity(
            weekStart: weekStart,
            days: [ReviewDayActivity(date: earlierDay, hasReflectiveActivity: true, hasPersistedEntry: true)]
        )
        let rhs = ReviewRhythmScrollPinIdentity(
            weekStart: weekStart,
            days: [ReviewDayActivity(date: laterDay, hasReflectiveActivity: true, hasPersistedEntry: true)]
        )
        XCTAssertNotEqual(lhs, rhs)
    }
}
