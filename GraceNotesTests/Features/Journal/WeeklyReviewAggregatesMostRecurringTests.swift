import XCTest
@testable import GraceNotes

final class WeeklyReviewAggregatesMostRecurringTests: XCTestCase {
    private var calendar: Calendar!
    private var builder: WeeklyReviewAggregatesBuilder!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1 // Sunday
        builder = WeeklyReviewAggregatesBuilder()
    }

    func test_buildMostRecurring_includesOneTimeThemesAndFullSurfaceEvidence() {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)
        let currentWeekEntries = [
            makeEntry(
                on: date(year: 2026, month: 3, day: 16),
                gratitudes: ["Family"],
                needs: ["Rest"],
                people: ["Mia"],
                readingNotes: "coffee",
                reflections: "coffee"
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 17),
                gratitudes: ["Family"],
                needs: ["Focus"],
                people: ["Coach"],
                readingNotes: "coffee",
                reflections: "coffee"
            )
        ]
        let previousWeekEntries = [
            makeEntry(
                on: previous.lowerBound,
                gratitudes: ["Family"]
            )
        ]
        let allEntries = previousWeekEntries + currentWeekEntries

        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            allEntries: allEntries,
            calendar: calendar
        )

        XCTAssertTrue(aggregates.stats.mostRecurringThemes.contains(where: { $0.totalCount == 1 }))
        XCTAssertTrue(
            aggregates.stats.mostRecurringThemes.contains(
                where: { theme in theme.evidence.contains(where: { $0.sources == [.people] }) }
            )
        )
        XCTAssertTrue(
            aggregates.stats.mostRecurringThemes.contains(
                where: { theme in
                    theme.evidence.contains(where: { $0.sources.contains(.readingNotes) || $0.sources.contains(.reflections) })
                }
            )
        )
    }

    func test_buildMostRecurring_usesEntireHistoryForRanking() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let currentWeekEntries = [
            makeEntry(on: date(year: 2026, month: 3, day: 18), gratitudes: ["Current"])
        ]
        let previousWeekEntries = [
            makeEntry(on: previous.lowerBound, gratitudes: ["Previous"])
        ]
        let historicalEntries = [
            makeEntry(on: date(year: 2026, month: 2, day: 1), gratitudes: ["Legacy"]),
            makeEntry(on: date(year: 2026, month: 2, day: 2), gratitudes: ["Legacy"]),
            makeEntry(on: date(year: 2026, month: 2, day: 3), gratitudes: ["Legacy"]),
            makeEntry(on: date(year: 2026, month: 2, day: 4), gratitudes: ["Legacy"]),
            makeEntry(on: date(year: 2026, month: 2, day: 5), gratitudes: ["Legacy"])
        ]

        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            allEntries: historicalEntries + previousWeekEntries + currentWeekEntries,
            calendar: calendar
        )

        let top = try XCTUnwrap(aggregates.stats.mostRecurringThemes.first)
        XCTAssertEqual(top.label, "Legacy")
        XCTAssertEqual(top.totalCount, 5)
    }

    func test_buildMostRecurring_trendUsesCurrentVsPreviousCalendarWeek() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        // Calendar-week targets for Sunday-first:
        // current week: 2026-03-15 ... 2026-03-21
        // previous week: 2026-03-08 ... 2026-03-14
        let entries = [
            // new: current > 0, previous = 0
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["New Theme"]),

            // up: current (2) > previous (1)
            makeEntry(on: date(year: 2026, month: 3, day: 9), gratitudes: ["Up Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["Up Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["Up Theme"]),

            // down: current (1) < previous (3)
            makeEntry(on: date(year: 2026, month: 3, day: 9), gratitudes: ["Down Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), gratitudes: ["Down Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 11), gratitudes: ["Down Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["Down Theme"]),

            // stable: current (2) == previous (2)
            makeEntry(on: date(year: 2026, month: 3, day: 9), gratitudes: ["Stable Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), gratitudes: ["Stable Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["Stable Theme"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["Stable Theme"])
        ]

        let currentWeekEntries = entries.filter { period.contains($0.entryDate) }
        let previousWeekEntries = entries.filter { previous.contains($0.entryDate) }
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            allEntries: entries,
            calendar: calendar
        )

        XCTAssertEqual(
            aggregates.stats.mostRecurringThemes.first(where: { $0.label == "New Theme" })?.trend,
            .new
        )
        XCTAssertEqual(
            aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Up Theme" })?.trend,
            .rising
        )
        XCTAssertEqual(
            aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Down Theme" })?.trend,
            .down
        )
        XCTAssertEqual(
            aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Stable Theme" })?.trend,
            .stable
        )
    }

    func test_buildMostRecurring_trendRespectsCalendarWeekBoundary() throws {
        let referenceDate = date(year: 2026, month: 3, day: 16) // Monday
        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 15), gratitudes: ["Boundary Theme"])
        ]

        var sundayCalendar = calendar!
        sundayCalendar.firstWeekday = 1
        let sundayPeriod = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: sundayCalendar)
        let sundayPrevious = ReviewInsightsPeriod.previousPeriod(before: sundayPeriod, calendar: sundayCalendar)
        let sundayAggregates = builder.build(
            currentPeriod: sundayPeriod,
            currentWeekEntries: entries.filter { sundayPeriod.contains($0.entryDate) },
            previousWeekEntries: entries.filter { sundayPrevious.contains($0.entryDate) },
            allEntries: entries,
            calendar: sundayCalendar
        )

        var mondayCalendar = calendar!
        mondayCalendar.firstWeekday = 2
        let mondayPeriod = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: mondayCalendar)
        let mondayPrevious = ReviewInsightsPeriod.previousPeriod(before: mondayPeriod, calendar: mondayCalendar)
        let mondayAggregates = builder.build(
            currentPeriod: mondayPeriod,
            currentWeekEntries: entries.filter { mondayPeriod.contains($0.entryDate) },
            previousWeekEntries: entries.filter { mondayPrevious.contains($0.entryDate) },
            allEntries: entries,
            calendar: mondayCalendar
        )

        XCTAssertEqual(
            sundayAggregates.stats.mostRecurringThemes.first(where: { $0.label == "Boundary Theme" })?.trend,
            .new
        )
        XCTAssertEqual(
            mondayAggregates.stats.mostRecurringThemes.first(where: { $0.label == "Boundary Theme" })?.trend,
            .down
        )
    }
}

private extension WeeklyReviewAggregatesMostRecurringTests {
    func makeEntry(
        on date: Date,
        gratitudes: [String] = [],
        needs: [String] = [],
        people: [String] = [],
        readingNotes: String = "",
        reflections: String = ""
    ) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: gratitudes.map { JournalItem(fullText: $0, chipLabel: $0) },
            needs: needs.map { JournalItem(fullText: $0, chipLabel: $0) },
            people: people.map { JournalItem(fullText: $0, chipLabel: $0) },
            readingNotes: readingNotes,
            reflections: reflections
        )
    }

    func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
