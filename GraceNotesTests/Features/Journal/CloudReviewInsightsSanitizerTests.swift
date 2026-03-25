import XCTest
@testable import GraceNotes

final class CloudReviewInsightsSanitizerTests: XCTestCase {

    func test_sanitize_replacesInterpretiveEnglishNarrative() {
        let sanitizer = CloudReviewInsightsSanitizer()
        let raw = CloudReviewInsightsPayload(
            narrativeSummary: "This shows that you value rest and family deeply.",
            resurfacingMessage: "You mentioned Rest 3 times and Family 2 times this week.",
            continuityPrompt: "What one step would support Rest tomorrow?",
            recurringGratitudes: [CloudReviewTheme(label: "Family", count: 2)],
            recurringNeeds: [CloudReviewTheme(label: "Rest", count: 3)],
            recurringPeople: []
        )

        let sanitized = sanitizer.sanitizePayload(raw)

        XCTAssertFalse(sanitized.narrativeSummary.lowercased().contains("shows that you"))
        XCTAssertTrue(sanitized.narrativeSummary.contains("Rest"))
        XCTAssertNoThrow(try sanitizer.validateGroundedQuality(sanitized))
    }

    func test_sanitize_replacesInterpretiveChineseNarrative() {
        let sanitizer = CloudReviewInsightsSanitizer()
        let raw = CloudReviewInsightsPayload(
            narrativeSummary: "这表明你在努力平衡工作与休息。",
            resurfacingMessage: "这周你多次写到「多休息」，也提到「晨祷」。",
            continuityPrompt: "明天能否为「多休息」留出十分钟？",
            recurringGratitudes: [CloudReviewTheme(label: "晨祷", count: 3)],
            recurringNeeds: [CloudReviewTheme(label: "多休息", count: 4)],
            recurringPeople: []
        )

        let sanitized = sanitizer.sanitizePayload(raw)

        XCTAssertFalse(sanitized.narrativeSummary.contains("表明你在"))
        XCTAssertTrue(sanitized.narrativeSummary.contains("多休息") || sanitized.narrativeSummary.contains("晨祷"))
        XCTAssertNoThrow(try sanitizer.validateGroundedQuality(sanitized))
    }

    func test_sanitize_repairsContinuityOrthogonalToThread() {
        let sanitizer = CloudReviewInsightsSanitizer()
        let raw = CloudReviewInsightsPayload(
            narrativeSummary: "Rest and Family both showed up often in your entries.",
            resurfacingMessage: "You noted Rest 3 times and Family 2 times this week.",
            continuityPrompt: "What new hobby will you start next year?",
            recurringGratitudes: [CloudReviewTheme(label: "Family", count: 2)],
            recurringNeeds: [CloudReviewTheme(label: "Rest", count: 3)],
            recurringPeople: []
        )

        let sanitized = sanitizer.sanitizePayload(raw)

        XCTAssertTrue(sanitized.continuityPrompt.contains("Rest") || sanitized.continuityPrompt.contains("Family"))
        XCTAssertNoThrow(try sanitizer.validateGroundedQuality(sanitized))
    }

    func test_validateGroundedQuality_emptyRecurringLists_throws() {
        let sanitizer = CloudReviewInsightsSanitizer()
        let payload = CloudReviewInsightsPayload(
            narrativeSummary: "You kept a calm rhythm.",
            resurfacingMessage: "You wrote often.",
            continuityPrompt: "What matters next?",
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: []
        )

        XCTAssertThrowsError(try sanitizer.validateGroundedQuality(payload)) { error in
            XCTAssertEqual(error as? CloudReviewInsightsError, .failedQualityGate)
        }
    }

    func test_sanitize_goodJuxtapositionNarrative_unchanged() {
        let sanitizer = CloudReviewInsightsSanitizer()
        let narrative = "ThemeA showed up alongside ThemeB on most days you wrote."
        let raw = CloudReviewInsightsPayload(
            narrativeSummary: narrative,
            resurfacingMessage: "You noted ThemeA 4 times and ThemeB 3 times this week.",
            continuityPrompt: "What is one small way to protect ThemeA tomorrow without dropping ThemeB?",
            recurringGratitudes: [CloudReviewTheme(label: "ThemeA", count: 4)],
            recurringNeeds: [CloudReviewTheme(label: "ThemeB", count: 3)],
            recurringPeople: []
        )

        let sanitized = sanitizer.sanitizePayload(raw)

        XCTAssertEqual(sanitized.narrativeSummary, narrative)
        XCTAssertNoThrow(try sanitizer.validateGroundedQuality(sanitized))
    }

    func test_sanitizeStructuredPayload_repairsInterpretiveNarrativeWithoutResurfacingRewrite() {
        let sanitizer = CloudReviewInsightsSanitizer()
        let observation = "You noted ThemeA 4 times and ThemeB 3 times this week."
        let raw = CloudReviewInsightsPayload(
            narrativeSummary: "This shows that you value ThemeA and ThemeB deeply.",
            resurfacingMessage: observation,
            continuityPrompt: "What is one small way to support ThemeA tomorrow without dropping ThemeB?",
            recurringGratitudes: [CloudReviewTheme(label: "ThemeA", count: 4)],
            recurringNeeds: [CloudReviewTheme(label: "ThemeB", count: 3)],
            recurringPeople: []
        )

        let sanitized = sanitizer.sanitizeStructuredPayload(raw)

        XCTAssertEqual(sanitized.resurfacingMessage, observation)
        XCTAssertFalse(sanitized.narrativeSummary.lowercased().contains("shows that you"))
        XCTAssertTrue(sanitized.narrativeSummary.contains("ThemeA"))
        XCTAssertNoThrow(try sanitizer.validateGroundedQuality(sanitized))
    }
}
