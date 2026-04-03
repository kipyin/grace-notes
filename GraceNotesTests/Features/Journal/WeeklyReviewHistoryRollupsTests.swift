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

        XCTAssertEqual(aggregates.stats.completionMix.bloomDayCount, 0)
        XCTAssertEqual(aggregates.stats.completionMix.sproutDayCount, 1)

        XCTAssertEqual(aggregates.stats.historyCompletionMix.bloomDayCount, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.sproutDayCount, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.soilDayCount, 0)

        XCTAssertEqual(
            aggregates.stats.historyCompletionMix.totalDaysRepresented,
            2,
            "Mix buckets wrap Past statistics interval (All) over `allEntries` days."
        )
    }

    func test_build_customPastStatisticsInterval_excludesDaysOutsideWindow() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)
        let ancient = date(year: 2025, month: 1, day: 1)
        let recent = date(year: 2026, month: 3, day: 17)
        let ancientEntry = makeEntry(on: ancient, gratitudes: ["old"])
        let recentEntry = makeEntry(on: recent, gratitudes: ["new"])
        let allEntries = [ancientEntry, recentEntry]
        let oneWeek = PastStatisticsIntervalSelection(mode: .custom, quantity: 1, unit: .week)
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: allEntries.filter { period.contains($0.entryDate) },
            previousWeekEntries: allEntries.filter { previous.contains($0.entryDate) },
            allEntries: allEntries,
            calendar: calendar,
            referenceDate: referenceDate,
            pastStatisticsInterval: oneWeek
        )
        XCTAssertEqual(aggregates.stats.historyCompletionMix.totalDaysRepresented, 1)
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
        XCTAssertEqual(aggregates.stats.historyCompletionMix.bloomDayCount, 1)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.soilDayCount, 0)
        XCTAssertEqual(aggregates.stats.historyCompletionMix.sproutDayCount, 0)
    }

    /// Skyline column order is weakest → strongest and matches monotonic ``tutorialCompletionRank`` (see
    /// `ReviewHistoryGrowthSkyline` in `ReviewHistoryInsightsPanels.swift`).
    func test_growthSkylineColumnOrder_matchesAscendingTutorialCompletionRank() {
        let columnOrder: [JournalCompletionLevel] = [.soil, .sprout, .twig, .leaf, .bloom]
        let ranks = columnOrder.map(\.tutorialCompletionRank)
        XCTAssertEqual(ranks, [0, 1, 2, 3, 4])
        for index in 0..<(ranks.count - 1) {
            XCTAssertLessThan(ranks[index], ranks[index + 1])
        }
    }

    func test_reviewHistoryWindowing_recomputesSameHistoryCompletionMixAsAggregates() throws {
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

        let interval = PastStatisticsIntervalSelection.default
        let windowed = ReviewHistoryWindowing.entriesInValidatedHistoryWindow(
            allEntries: allEntries,
            referenceDate: referenceDate,
            calendar: calendar,
            pastStatisticsInterval: interval
        )
        let strongest = ReviewHistoryWindowing.strongestCompletionByDay(from: windowed, calendar: calendar)
        let recomputed = Self.completionMix(fromStrongestByDay: strongest)
        XCTAssertEqual(recomputed, aggregates.stats.historyCompletionMix)
    }

    func test_reviewHistoryWindowing_calendarDaysMatchingLevel_reflectsStrongestPerDay() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let sharedDay = date(year: 2026, month: 3, day: 16)

        let sparseSameDay = makeEntry(on: sharedDay, gratitudes: ["x"])
        let fullSameDay = makeEntry(
            on: sharedDay,
            gratitudes: (0..<5).map { "g\($0)" },
            needs: (0..<5).map { "n\($0)" },
            people: (0..<5).map { "p\($0)" }
        )
        let allEntries = [sparseSameDay, fullSameDay]
        let windowed = ReviewHistoryWindowing.entriesInValidatedHistoryWindow(
            allEntries: allEntries,
            referenceDate: referenceDate,
            calendar: calendar,
            pastStatisticsInterval: .default
        )
        let strongest = ReviewHistoryWindowing.strongestCompletionByDay(from: windowed, calendar: calendar)
        let fullDays = ReviewHistoryWindowing.calendarDaysMatchingStrongestCompletionLevel(
            .bloom,
            strongestByDay: strongest
        )
        XCTAssertEqual(fullDays.count, 1)
        XCTAssertEqual(
            ReviewHistoryWindowing.calendarDaysMatchingStrongestCompletionLevel(
                .sprout,
                strongestByDay: strongest
            ).count,
            0
        )
    }

    func test_rhythmHistory_startsAtEarliestEntry_notClippedToFixedShortWindow() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let ancient = date(year: 2025, month: 1, day: 1)
        let recent = date(year: 2026, month: 3, day: 17)
        let ancientEntry = makeEntry(on: ancient, gratitudes: ["old"])
        let recentEntry = makeEntry(on: recent, gratitudes: ["new"])
        let allEntries = [ancientEntry, recentEntry]

        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: allEntries.filter { period.contains($0.entryDate) },
            previousWeekEntries: allEntries.filter { previous.contains($0.entryDate) },
            allEntries: allEntries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let rhythm = try XCTUnwrap(aggregates.stats.rhythmHistory)
        XCTAssertEqual(calendar.startOfDay(for: rhythm.first!.date), calendar.startOfDay(for: ancient))
        XCTAssertGreaterThan(rhythm.count, 180, "Uncapped history should span ancient entry through week end.")
    }

    func test_reviewHistoryWindowing_entriesContributingToSection_sortsNewestFirst() {
        let dayOlder = date(year: 2026, month: 3, day: 10)
        let dayNewer = date(year: 2026, month: 3, day: 11)
        let older = makeEntry(on: dayOlder, gratitudes: ["a"])
        let newer = makeEntry(on: dayNewer, needs: ["n"])
        let sortedOldestFirst = ReviewHistoryWindowing.sortedEntries([newer, older])
        let gratitudesOnly = ReviewHistoryWindowing.entriesContributingToSection(
            .gratitudes,
            in: sortedOldestFirst
        )
        XCTAssertEqual(gratitudesOnly.map(\.entryDate), [dayOlder])
        let needsOnly = ReviewHistoryWindowing.entriesContributingToSection(.needs, in: sortedOldestFirst)
        XCTAssertEqual(needsOnly.map(\.entryDate), [dayNewer])
    }
}

private extension WeeklyReviewHistoryRollupsTests {
    static func completionMix(
        fromStrongestByDay strongestByDay: [Date: JournalCompletionLevel]
    ) -> ReviewWeekCompletionMix {
        var soilDayCount = 0
        var sproutDayCount = 0
        var twigDayCount = 0
        var leafDayCount = 0
        var bloomDayCount = 0
        for level in strongestByDay.values {
            switch level {
            case .soil:
                soilDayCount += 1
            case .sprout:
                sproutDayCount += 1
            case .twig:
                twigDayCount += 1
            case .leaf:
                leafDayCount += 1
            case .bloom:
                bloomDayCount += 1
            }
        }
        return ReviewWeekCompletionMix(
            soilDayCount: soilDayCount,
            sproutDayCount: sproutDayCount,
            twigDayCount: twigDayCount,
            leafDayCount: leafDayCount,
            bloomDayCount: bloomDayCount
        )
    }

    func distinctEntryDays(_ entries: [Journal]) -> Int {
        Set(entries.map { calendar.startOfDay(for: $0.entryDate) }).count
    }

    func makeEntry(
        on date: Date,
        gratitudes: [String] = [],
        needs: [String] = [],
        people: [String] = [],
        readingNotes: String = "",
        reflections: String = ""
    ) -> Journal {
        Journal(
            entryDate: date,
            gratitudes: gratitudes.map { Entry(fullText: $0) },
            needs: needs.map { Entry(fullText: $0) },
            people: people.map { Entry(fullText: $0) },
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
