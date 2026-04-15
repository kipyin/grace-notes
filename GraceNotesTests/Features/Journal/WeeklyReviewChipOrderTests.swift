import XCTest
@testable import GraceNotes

/// Locks in recurring chip tie order (`firstSeenOrder` before label) vs ``sortedThemeSummaries``.
final class WeeklyReviewChipOrderTests: XCTestCase {
    private var calendar: Calendar!
    private var builder: WeeklyReviewAggregatesBuilder!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1 // Sunday
        builder = WeeklyReviewAggregatesBuilder()
    }

    /// When mention/day counts tie across many chip themes, recurring chips follow `firstSeenOrder` (scan order)
    /// before localized label—same tie stack as ``sortedThemeSummaries`` for chip-only aggregates.
    func test_recurringChips_breakTiesOnFirstSeenOrderBeforeLabel() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let sameDay = date(year: 2026, month: 3, day: 17)
        // Not alphabetical: if ties fell through to label only, "Apple" would beat "Zebra".
        let entries = [
            makeEntry(on: sameDay, gratitudes: ["Zebra", "Apple", "Mango", "Banana"])
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let gratitudeSummaries = aggregates.candidateInputs.gratitudes
        let expectedTopThree = Array(gratitudeSummaries.prefix(3)).map(\.displayLabel)

        XCTAssertEqual(
            aggregates.recurringGratitudes.map(\.label),
            ["Zebra", "Apple", "Mango"],
            "Top recurring chips should follow journal/chip scan order when mention and day counts are fully tied."
        )
        XCTAssertEqual(
            aggregates.recurringGratitudes.map(\.label),
            expectedTopThree,
            """
            Recurring gratitude chips should mirror the first three `ThemeSummary` rows from chip aggregation \
            for the same tie scenario.
            """
        )
    }

    func test_recurringNeedsAndPeople_breakTiesOnFirstSeenOrderBeforeLabel() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let sameDay = date(year: 2026, month: 3, day: 17)
        let entries = [
            makeEntry(
                on: sameDay,
                needs: ["Zebra", "Apple", "Mango", "Banana"],
                people: ["Yvonne", "Alex", "Quinn", "Pat"]
            )
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(aggregates.recurringNeeds.map(\.label), ["Zebra", "Apple", "Mango"])
        XCTAssertEqual(aggregates.recurringPeople.map(\.label), ["Yvonne", "Alex", "Quinn"])

        XCTAssertEqual(
            aggregates.recurringNeeds.map(\.label),
            Array(aggregates.candidateInputs.needs.prefix(3)).map(\.displayLabel)
        )
        XCTAssertEqual(
            aggregates.recurringPeople.map(\.label),
            Array(aggregates.candidateInputs.people.prefix(3)).map(\.displayLabel)
        )
    }
}

private extension WeeklyReviewChipOrderTests {
    func makeEntry(
        on date: Date,
        gratitudes: [String] = [],
        needs: [String] = [],
        people: [String] = []
    ) -> Journal {
        Journal(
            entryDate: date,
            gratitudes: gratitudes.map { Entry(fullText: $0) },
            needs: needs.map { Entry(fullText: $0) },
            people: people.map { Entry(fullText: $0) },
            readingNotes: "",
            reflections: ""
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
