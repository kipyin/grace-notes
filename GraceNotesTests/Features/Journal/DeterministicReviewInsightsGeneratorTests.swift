import XCTest
@testable import GraceNotes

final class DeterministicReviewInsightsTests: XCTestCase {
    private var calendar: Calendar!
    private var generator: DeterministicReviewInsightsGenerator!

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
            makeFullEntry(on: date(year: 2026, month: 3, day: 12 + offset))
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
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            "Start with one reflection today to build your weekly review."
        )
    }

    func test_generateInsights_limitsInsightCountToTwo() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let previousWeekEntries = [
            makeEntry(on: date(year: 2026, month: 3, day: 9), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 11), needs: ["Rest"])
        ]
        let currentWeekEntries = [
            makeEntry(
                on: date(year: 2026, month: 3, day: 16),
                gratitudes: ["Family"],
                needs: ["Focus"],
                people: ["Mia"]
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 17),
                gratitudes: ["Family"],
                needs: ["Focus"],
                people: ["Mia"]
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 18),
                gratitudes: ["Family"],
                needs: ["Focus"],
                people: ["Mia"]
            )
        ]

        let insights = try await generator.generateInsights(
            from: previousWeekEntries + currentWeekEntries,
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertLessThanOrEqual(insights.weeklyInsights.count, 2)
    }

    func test_generateInsights_withoutEntries_returnsStarterGuidance() async throws {
        let reference = date(year: 2026, month: 3, day: 18)

        let insights = try await generator.generateInsights(
            from: [],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(
            insights.resurfacingMessage,
            "Start with one reflection today to build your weekly review."
        )
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(
            insights.narrativeSummary,
            "Start with one reflection today to build your weekly review."
        )
    }

    func test_generateInsights_preservesOriginalMixedLanguageLabelWhileGroupingCaseInsensitively() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let first = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            gratitudes: ["morning coffee 讓我安定"]
        )
        let second = makeEntry(
            on: date(year: 2026, month: 3, day: 18),
            gratitudes: ["Morning Coffee 讓我安定"]
        )

        let insights = try await generator.generateInsights(
            from: [first, second],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringGratitudes.first?.label, "morning coffee 讓我安定")
        XCTAssertEqual(insights.recurringGratitudes.first?.count, 2)
    }

    func test_generateInsights_usesReadingNotesAndReflectionsAsExtraSignal() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let first = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            readingNotes: "I kept thinking about boundaries and rest",
            reflections: "Boundaries helped me protect focus."
        )
        let second = makeEntry(
            on: date(year: 2026, month: 3, day: 18),
            readingNotes: "Rest and boundaries came up again",
            reflections: "I need better boundaries tomorrow."
        )

        let insights = try await generator.generateInsights(
            from: [first, second],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertFalse(insights.weeklyInsights.isEmpty)
        XCTAssertTrue(insights.narrativeSummary?.isEmpty == false)
    }

    private func makeEntry(
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

    private func makeFullEntry(on date: Date) -> JournalEntry {
        let gratitudes = (1...5).map { JournalItem(fullText: "Gratitude \($0)", chipLabel: "Gratitude \($0)") }
        let needs = (1...5).map { JournalItem(fullText: "Need \($0)", chipLabel: "Need \($0)") }
        let people = (1...5).map { JournalItem(fullText: "Person \($0)", chipLabel: "Person \($0)") }
        return JournalEntry(
            entryDate: date,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: "Reading notes",
            reflections: "Reflections"
        )
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
