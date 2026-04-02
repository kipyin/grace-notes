import XCTest
@testable import GraceNotes

final class DeterministicReviewInsightsTests: XCTestCase {
    var calendar: Calendar!
    var generator: DeterministicReviewInsightsGenerator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        generator = DeterministicReviewInsightsGenerator()
    }

    func test_generateInsights_usesCurrentReviewPeriodOnly() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let inWeekEntry = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            gratitudes: ["Family"]
        )
        let previousWeekEntry = makeEntry(
            on: date(year: 2026, month: 3, day: 8),
            gratitudes: ["Travel"]
        )

        let insights = try await generator.generateInsights(
            from: [inWeekEntry, previousWeekEntry],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringGratitudes.first?.label, "Family")
        XCTAssertFalse(insights.recurringGratitudes.contains(where: { $0.label == "Travel" }))
    }

    func test_generateInsights_generatesRecurringPeopleInsight() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let first = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            gratitudes: ["Family one"],
            needs: ["Rest one"],
            people: ["Mia"]
        )
        let second = makeEntry(
            on: date(year: 2026, month: 3, day: 18),
            gratitudes: ["Family two"],
            needs: ["Rest two"],
            people: ["Mia"]
        )

        let insights = try await generator.generateInsights(
            from: [first, second],
            referenceDate: reference,
            calendar: calendar
        )

        let recurringPersonInsight = insights.weeklyInsights.first { $0.pattern == .recurringPeople }
        XCTAssertNotNil(recurringPersonInsight)
        XCTAssertTrue(recurringPersonInsight?.observation.contains("Mia") == true)
    }

    func test_generateInsights_generatesNeedsGratitudeGapInsight() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let first = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            gratitudes: ["Family"],
            needs: ["Rest"],
            people: ["Mia"]
        )
        let second = makeEntry(
            on: date(year: 2026, month: 3, day: 18),
            gratitudes: ["Family"],
            needs: ["Rest"],
            people: ["Mia"]
        )

        let insights = try await generator.generateInsights(
            from: [first, second],
            referenceDate: reference,
            calendar: calendar
        )

        let gapInsight = insights.weeklyInsights.first { $0.pattern == .needsGratitudeGap }
        XCTAssertNotNil(gapInsight)
        XCTAssertEqual(gapInsight?.primaryTheme, "Rest")
    }

    func test_generateInsights_generatesContinuityShiftInsight() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let previousWeekEntries = [
            makeEntry(on: date(year: 2026, month: 3, day: 9), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 11), needs: ["Rest"])
        ]
        let currentWeekEntries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["Family connection"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["Family connection"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), gratitudes: ["Family connection"])
        ]

        let insights = try await generator.generateInsights(
            from: previousWeekEntries + currentWeekEntries,
            referenceDate: reference,
            calendar: calendar
        )

        let shiftInsight = insights.weeklyInsights.first { $0.pattern == .continuityShift }
        XCTAssertNotNil(shiftInsight)
        XCTAssertTrue(shiftInsight?.observation.contains("Rest") == true)
        XCTAssertTrue(shiftInsight?.observation.contains("Family connection") == true)
    }

    func test_generateInsights_generatesFullCompletionInsight_forSevenFullDays() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let fullWeekEntries = (0...6).map { offset in
            makeFullEntry(on: date(year: 2026, month: 3, day: 16 + offset))
        }

        let insights = try await generator.generateInsights(
            from: fullWeekEntries,
            referenceDate: reference,
            calendar: calendar
        )

        let completionInsight = insights.weeklyInsights.first { $0.pattern == .fullCompletion }
        XCTAssertNotNil(completionInsight)
        XCTAssertEqual(completionInsight?.dayCount, 7)
    }

    func test_generateInsights_activityTracksStrongestCompletionPerDay() async throws {
        let reference = date(year: 2026, month: 3, day: 19)
        let seedDay = date(year: 2026, month: 3, day: 17)
        let harvestDay = date(year: 2026, month: 3, day: 18)
        let textOnlyDay = date(year: 2026, month: 3, day: 19)
        let insights = try await generator.generateInsights(
            from: [
                makeEntry(on: seedDay, gratitudes: ["Family"], needs: ["Rest"], people: ["Mia"]),
                JournalEntry(
                    entryDate: harvestDay,
                    gratitudes: (1...5).map { JournalItem(fullText: "Gratitude \($0)") },
                    needs: (1...5).map { JournalItem(fullText: "Need \($0)") },
                    people: (1...5).map { JournalItem(fullText: "Person \($0)") }
                ),
                makeEntry(on: textOnlyDay, readingNotes: "Short note from the day")
            ],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(
            insights.weekStats.activity
                .first(where: { calendar.isDate($0.date, inSameDayAs: seedDay) })?
                .strongestCompletionLevel,
            .sprout
        )
        XCTAssertEqual(
            insights.weekStats.activity
                .first(where: { calendar.isDate($0.date, inSameDayAs: harvestDay) })?
                .strongestCompletionLevel,
            .bloom
        )
        XCTAssertEqual(
            insights.weekStats.activity
                .first(where: { calendar.isDate($0.date, inSameDayAs: textOnlyDay) })?
                .strongestCompletionLevel,
            .soil
        )
    }

    func test_generateInsights_returnsSparseFallback_whenSignalsAreTooLow() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let oneEmptyEntry = makeEntry(on: date(year: 2026, month: 3, day: 17))

        let insights = try await generator.generateInsights(
            from: [oneEmptyEntry],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.weeklyInsights.count, 1)
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(insights.presentationMode, .statsFirst)
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            String(localized: "Start with one reflection today to build your weekly review.")
        )
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
            gratitudes: gratitudes.map { JournalItem(fullText: $0) },
            needs: needs.map { JournalItem(fullText: $0) },
            people: people.map { JournalItem(fullText: $0) },
            readingNotes: readingNotes,
            reflections: reflections
        )
    }

    func makeFullEntry(on date: Date) -> JournalEntry {
        let gratitudes = (1...5).map { JournalItem(fullText: "Gratitude \($0)") }
        let needs = (1...5).map { JournalItem(fullText: "Need \($0)") }
        let people = (1...5).map { JournalItem(fullText: "Person \($0)") }
        return JournalEntry(
            entryDate: date,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: "Reading notes",
            reflections: "Reflections"
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
