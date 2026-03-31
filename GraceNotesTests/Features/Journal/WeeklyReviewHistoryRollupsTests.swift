import XCTest
@testable import GraceNotes

final class WeeklyReviewHistoryRollupsTests: XCTestCase {
    private var calendar: Calendar!
    private var builder: WeeklyReviewAggregatesBuilder!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        builder = WeeklyReviewAggregatesBuilder()
    }

    /// Week stats use current-week entries only; history stats use sorted ``allEntries``.
    func test_build_historySectionTotalsAndCompletionMix_spanAllEntries() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let priorMonth = date(year: 2026, month: 2, day: 1)
        let fullDayChips = (0..<5).map { "a\($0)" }
        let priorFull = makeEntry(
            on: priorMonth,
            gratitudes: fullDayChips,
            needs: fullDayChips,
            people: fullDayChips
        )
        let weekSparse = makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["solo"])

        let allEntries = [priorFull, weekSparse]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: allEntries.filter { period.contains($0.entryDate) },
            previousWeekEntries: allEntries.filter { previous.contains($0.entryDate) },
            allEntries: allEntries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(aggregates.stats.sectionTotals.gratitudeMentions, 1)
        XCTAssertEqual(aggregates.stats.sectionTotals.needMentions, 0)
        XCTAssertEqual(aggregates.stats.sectionTotals.peopleMentions, 0)

        XCTAssertEqual(aggregates.stats.historySectionTotals.gratitudeMentions, 6)
        XCTAssertEqual(aggregates.stats.historySectionTotals.needMentions, 5)
        XCTAssertEqual(aggregates.stats.historySectionTotals.peopleMentions, 5)

        XCTAssertEqual(aggregates.stats.completionMix.fullDays, 0)
        XCTAssertEqual(aggregates.stats.completionMix.startedDays, 1)

        XCTAssertEqual(aggregates.stats.historyCompletionMix.fullDays, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.startedDays, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.emptyDays, 0)

        XCTAssertEqual(
            aggregates.stats.historyCompletionMix.totalDaysRepresented,
            2,
            "Mix buckets sum to calendar days with ≥1 persisted entry in allEntries."
        )
    }

    /// Week-scoped mix counts only days in ``currentPeriod``; history mix counts all days in ``allEntries``.
    func test_build_weekMix_and_historyMix_useDifferentEntryDaySets() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let inWeek = date(year: 2026, month: 3, day: 17)
        let outsideWeek = date(year: 2026, month: 2, day: 1)

        let weekEntry = makeEntry(on: inWeek, gratitudes: ["only"])
        let outsideEntry = makeEntry(
            on: outsideWeek,
            gratitudes: (0..<5).map { "g\($0)" },
            needs: (0..<5).map { "n\($0)" },
            people: (0..<5).map { "p\($0)" }
        )

        let allEntries = [outsideEntry, weekEntry]
        let weekSlice = allEntries.filter { period.contains($0.entryDate) }

        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: weekSlice,
            previousWeekEntries: allEntries.filter { previous.contains($0.entryDate) },
            allEntries: allEntries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(distinctEntryDays(weekSlice), 1)
        XCTAssertEqual(aggregates.stats.completionMix.totalDaysRepresented, 1)

        XCTAssertEqual(distinctEntryDays(allEntries), 2)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.totalDaysRepresented, 2)
    }

    /// Strongest completion wins when several persisted rows share a calendar day (invariant still one day).
    func test_historyCompletionMix_oneDayPerCalendarDayDespiteMultipleEntries() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)
        let sharedDay = date(year: 2026, month: 3, day: 16)

        let sparseSameDay = makeEntry(on: sharedDay, gratitudes: ["x"])
        let fullSameDay = makeEntry(
            on: sharedDay,
            gratitudes: (0..<5).map { "g\($0)" },
            needs: (0..<5).map { "n\($0)" },
            people: (0..<5).map { "p\($0)" }
        )
        let allEntries = [sparseSameDay, fullSameDay]

        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: allEntries.filter { period.contains($0.entryDate) },
            previousWeekEntries: allEntries.filter { previous.contains($0.entryDate) },
            allEntries: allEntries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(distinctEntryDays(allEntries), 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.totalDaysRepresented, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.fullDays, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.emptyDays, 0)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.startedDays, 0)
    }

    /// Skyline column order is weakest → strongest and matches monotonic ``tutorialCompletionRank`` (see
    /// `ReviewHistoryGrowthSkyline` in `ReviewHistoryInsightsPanels.swift`).
    func test_growthSkylineColumnOrder_matchesAscendingTutorialCompletionRank() {
        let columnOrder: [JournalCompletionLevel] = [.empty, .started, .growing, .balanced, .full]
        let ranks = columnOrder.map(\.tutorialCompletionRank)
        XCTAssertEqual(ranks, [0, 1, 2, 3, 4])
        for index in 0..<(ranks.count - 1) {
            XCTAssertLessThan(ranks[index], ranks[index + 1])
        }
    }
}

private extension WeeklyReviewHistoryRollupsTests {
    func distinctEntryDays(_ entries: [JournalEntry]) -> Int {
        Set(entries.map { calendar.startOfDay(for: $0.entryDate) }).count
    }

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
