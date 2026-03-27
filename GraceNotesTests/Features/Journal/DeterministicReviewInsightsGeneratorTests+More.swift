import XCTest
@testable import GraceNotes

extension DeterministicReviewInsightsTests {
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
        XCTAssertEqual(insights.presentationMode, .insight)
        XCTAssertEqual(insights.weekStats.reflectionDays, 3)
    }

    func test_generateInsights_includesWeekStatsActivityAndCompletionMix() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let entries = [
            makeFullEntry(on: date(year: 2026, month: 3, day: 17)),
            makeEntry(on: date(year: 2026, month: 3, day: 18), gratitudes: ["Family"], needs: ["Rest"], people: ["Mia"])
        ]

        let insights = try await generator.generateInsights(
            from: entries,
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.weekStats.activity.count, 7)
        XCTAssertEqual(insights.weekStats.reflectionDays, 2)
        XCTAssertEqual(insights.weekStats.meaningfulEntryCount, 2)
        XCTAssertEqual(insights.weekStats.completionMix.fullDays, 1)
        XCTAssertEqual(insights.weekStats.completionMix.startedDays, 1)
        XCTAssertEqual(insights.weekStats.sectionTotals.gratitudeMentions, 6)
        XCTAssertEqual(insights.weekStats.sectionTotals.needMentions, 6)
        XCTAssertEqual(insights.weekStats.sectionTotals.peopleMentions, 6)
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
        XCTAssertNil(insights.narrativeSummary)
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
}
