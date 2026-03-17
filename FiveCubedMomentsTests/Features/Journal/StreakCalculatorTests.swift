import XCTest
@testable import FiveCubedMoments

final class StreakCalculatorTests: XCTestCase {
    private var calendar: Calendar!
    private var calculator: StreakCalculator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calculator = StreakCalculator(calendar: calendar)
    }

    func test_blankAutoCreatedEntry_doesNotCountAsBasicStreak() {
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let blankToday = makeEntry(on: date(year: 2026, month: 3, day: 17, hour: 8))

        let summary = calculator.summary(from: [blankToday], now: now)

        XCTAssertEqual(summary.basicCurrent, 0)
        XCTAssertEqual(summary.perfectCurrent, 0)
    }

    func test_partialEntry_countsAsBasicNotPerfect() {
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let partialToday = makeEntry(
            on: date(year: 2026, month: 3, day: 17, hour: 9),
            gratitudes: [JournalItem(fullText: "Family", chipLabel: nil)]
        )

        let summary = calculator.summary(from: [partialToday], now: now)

        XCTAssertEqual(summary.basicCurrent, 1)
        XCTAssertEqual(summary.perfectCurrent, 0)
        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertFalse(summary.perfectDoneToday)
    }

    func test_completeEntry_countsAsBasicAndPerfect() {
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let completeToday = makeCompleteEntry(on: date(year: 2026, month: 3, day: 17, hour: 10))

        let summary = calculator.summary(from: [completeToday], now: now)

        XCTAssertEqual(summary.basicCurrent, 1)
        XCTAssertEqual(summary.perfectCurrent, 1)
        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertTrue(summary.perfectDoneToday)
    }

    func test_streakBreakAcrossSkippedDay_resetsCurrentStreak() {
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let twoDaysAgo = makeEntry(
            on: date(year: 2026, month: 3, day: 15, hour: 11),
            gratitudes: [JournalItem(fullText: "Grateful", chipLabel: nil)]
        )

        let summary = calculator.summary(from: [twoDaysAgo], now: now)

        XCTAssertEqual(summary.basicCurrent, 0)
        XCTAssertEqual(summary.perfectCurrent, 0)
    }

    func test_dateNormalization_usesCalendarDayBoundaries() {
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let lateYesterday = makeEntry(
            on: date(year: 2026, month: 3, day: 16, hour: 23, minute: 59),
            gratitudes: [JournalItem(fullText: "Late note", chipLabel: nil)]
        )
        let earlyToday = makeEntry(
            on: date(year: 2026, month: 3, day: 17, hour: 0, minute: 1),
            gratitudes: [JournalItem(fullText: "Early note", chipLabel: nil)]
        )

        let summary = calculator.summary(from: [lateYesterday, earlyToday], now: now)

        XCTAssertEqual(summary.basicCurrent, 2)
    }

    private func makeEntry(
        on date: Date,
        gratitudes: [JournalItem] = [],
        needs: [JournalItem] = [],
        people: [JournalItem] = [],
        readingNotes: String = "",
        reflections: String = "",
        completedAt: Date? = nil
    ) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: readingNotes,
            reflections: reflections,
            completedAt: completedAt
        )
    }

    private func makeCompleteEntry(on date: Date) -> JournalEntry {
        let items = (1...JournalEntry.slotCount).map {
            JournalItem(fullText: "Item \($0)", chipLabel: nil)
        }
        return makeEntry(
            on: date,
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "Psalm 23",
            reflections: "Today was meaningful",
            completedAt: date
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
