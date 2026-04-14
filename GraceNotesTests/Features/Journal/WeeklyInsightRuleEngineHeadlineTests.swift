import XCTest
@testable import GraceNotes

final class WeeklyInsightRuleEngineHeadlineTests: XCTestCase {
    func test_firstNonEmptyTrimmedHeadline_prefersFirstObservationAcrossAllInsightsBeforeAnyTheme() {
        let insights = [
            ReviewWeeklyInsight(
                pattern: .sparseFallback,
                observation: "   ",
                action: nil,
                primaryTheme: "Earlier theme",
                mentionCount: nil,
                dayCount: nil
            ),
            ReviewWeeklyInsight(
                pattern: .recurringTheme,
                observation: "Later observation wins",
                action: nil,
                primaryTheme: "Other theme",
                mentionCount: nil,
                dayCount: nil
            )
        ]
        XCTAssertEqual(
            WeeklyInsightRuleEngine.firstNonEmptyTrimmedHeadline(in: insights),
            "Later observation wins"
        )
    }

    func test_firstNonEmptyTrimmedHeadline_usesPrimaryThemeWhenObservationsAreBlank() {
        let insights = [
            ReviewWeeklyInsight(
                pattern: .sparseFallback,
                observation: "\n\t ",
                action: nil,
                primaryTheme: "  Theme headline  ",
                mentionCount: nil,
                dayCount: nil
            )
        ]
        XCTAssertEqual(
            WeeklyInsightRuleEngine.firstNonEmptyTrimmedHeadline(in: insights),
            "Theme headline"
        )
    }
}
