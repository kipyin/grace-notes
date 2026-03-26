import XCTest
@testable import GraceNotes

extension DeterministicReviewInsightsTests {
    func test_weeklyInsightCandidateBuilder_narrativeSummary_usesSecondObservationWhenDistinct() {
        let builder = WeeklyInsightCandidateBuilder(textNormalizer: WeeklyInsightTextNormalizer())
        let first = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: "Alpha observation line.",
            action: "Q1?",
            primaryTheme: "Alpha",
            mentionCount: 2,
            dayCount: 2
        )
        let second = ReviewWeeklyInsight(
            pattern: .continuityShift,
            observation: "Beta observation line.",
            action: "Q2?",
            primaryTheme: "Beta",
            mentionCount: 2,
            dayCount: 2
        )
        XCTAssertEqual(builder.narrativeSummary(from: [first, second]), "Beta observation line.")
    }

    func test_weeklyInsightCandidateBuilder_narrativeSummary_whenObservationsDuplicate_usesBothThemesLine() {
        let builder = WeeklyInsightCandidateBuilder(textNormalizer: WeeklyInsightTextNormalizer())
        let shared = "Same observation text."
        let first = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: shared,
            action: "Q1?",
            primaryTheme: "Rest",
            mentionCount: 2,
            dayCount: 2
        )
        let second = ReviewWeeklyInsight(
            pattern: .recurringPeople,
            observation: shared,
            action: "Q2?",
            primaryTheme: "Mia",
            mentionCount: 2,
            dayCount: 2
        )
        let summary = builder.narrativeSummary(from: [first, second])
        XCTAssertTrue(summary?.contains("Rest") == true)
        XCTAssertTrue(summary?.contains("Mia") == true)
    }

    func test_weeklyInsightCandidateBuilder_narrativeSummary_sparseFallbackZeroDay_returnsNil() {
        let builder = WeeklyInsightCandidateBuilder(textNormalizer: WeeklyInsightTextNormalizer())
        let starter = String(localized: "Start with one reflection today to build your weekly review.")
        let insight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: starter,
            action: builder.defaultContinuityPrompt,
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: 0
        )
        XCTAssertNil(builder.narrativeSummary(from: [insight]))
    }

    func test_weeklyInsightCandidateBuilder_narrativeSummary_sparseFallbackNonZeroDay_returnsTrimmed() {
        let builder = WeeklyInsightCandidateBuilder(textNormalizer: WeeklyInsightTextNormalizer())
        let observation = "  Sparse week summary line.  "
        let easyStart = String(localized: "What would make tomorrow's check-in easy to start?")
        let insight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: observation,
            action: easyStart,
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: 1
        )
        let summary = builder.narrativeSummary(from: [insight])
        let trimmed = observation.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(summary, trimmed)
    }
}
