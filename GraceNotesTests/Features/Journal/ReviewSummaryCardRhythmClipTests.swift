import XCTest
@testable import GraceNotes

final class ReviewSummaryCardRhythmClipTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
    }

    /// Mid-week reference: only days from week start through Wednesday appear.
    func test_rhythmDaysVisibleForDisplay_clipsFutureDaysInCurrentWeek() {
        let weekStart = date(year: 2026, month: 3, day: 15)
        let weekEndExclusive = date(year: 2026, month: 3, day: 22)
        let days = (0..<7).map { offset -> ReviewDayActivity in
            let d = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            return ReviewDayActivity(date: d, hasReflectiveActivity: false, hasPersistedEntry: false)
        }
        let referenceWednesday = date(year: 2026, month: 3, day: 18)
        let clipped = ReviewDaysYouWrotePanel.rhythmDaysVisibleForDisplay(
            days,
            weekEndExclusive: weekEndExclusive,
            referenceNow: referenceWednesday,
            calendar: calendar
        )
        XCTAssertEqual(clipped.count, 4)
        XCTAssertEqual(calendar.startOfDay(for: clipped.last!.date), referenceWednesday)
    }

    /// Fully elapsed week: all seven days remain (clip end is last day of that week, not “today”).
    func test_rhythmDaysVisibleForDisplay_pastWeek_keepsAllSevenDays() {
        let weekStart = date(year: 2026, month: 3, day: 8)
        let weekEndExclusive = date(year: 2026, month: 3, day: 15)
        let days = (0..<7).map { offset -> ReviewDayActivity in
            let d = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            return ReviewDayActivity(date: d, hasReflectiveActivity: true, hasPersistedEntry: true)
        }
        let laterReference = date(year: 2026, month: 3, day: 25)
        let clipped = ReviewDaysYouWrotePanel.rhythmDaysVisibleForDisplay(
            days,
            weekEndExclusive: weekEndExclusive,
            referenceNow: laterReference,
            calendar: calendar
        )
        XCTAssertEqual(clipped.count, 7)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
