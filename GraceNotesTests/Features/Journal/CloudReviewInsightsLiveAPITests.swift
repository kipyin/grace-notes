import XCTest
@testable import GraceNotes

/// End-to-end check against the configured OpenAI-compatible endpoint (real network).
///
/// **Skipped** when no usable key is available, or on CI (unless `GRACENOTES_LIVE_CLOUD_API_KEY` is set there).
///
/// **Local + usable app key** (build-injected `CloudSummarizationAPIKey` via xcconfig): the test runs automatically.
/// Simulator tests do not inherit shell environment variables from `xcodebuild`, so the app bundle plist is the
/// reliable path from Xcode.
///
/// **Opt-out** (local key present but you want offline tests): set `GRACENOTES_SKIP_LIVE_CLOUD_INSIGHTS=1` on the test
/// scheme.
///
/// **Override key**: `GRACENOTES_LIVE_CLOUD_API_KEY` (highest priority).
///
/// Assertions cover: no `missingContent`, successful decode, quality gate, and non-empty grounded copy.
final class CloudReviewInsightsLiveAPITests: XCTestCase {
    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    /// Same review period as ``CloudReviewInsightsGeneratorTests`` (seven calendar days ending on reference).
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 18
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return testCalendar.date(from: components)!
    }()

    private static func skipInstructions() -> String {
        """
        Live cloud insights test skipped. Configure GRACE_NOTES_CLOUD_API_KEY \
        (DeveloperSettings.local.xcconfig) or pass GRACENOTES_LIVE_CLOUD_API_KEY into the test process. \
        On CI this test stays offline unless that env var is set.
        """
    }

    private static var isRunningOnCI: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["CI"] == "true"
            || env["GITHUB_ACTIONS"] == "true"
            || env["BITRISE_IO"] == "true"
    }

    private static func resolveLiveAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["GRACENOTES_LIVE_CLOUD_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            ApiSecrets.isUsableCloudApiKey(env) {
            return env
        }
        if ProcessInfo.processInfo.environment["GRACENOTES_SKIP_LIVE_CLOUD_INSIGHTS"] == "1" {
            return nil
        }
        if isRunningOnCI {
            return nil
        }
        if ApiSecrets.isCloudApiKeyConfigured {
            return ApiSecrets.cloudApiKey
        }
        return nil
    }

    func test_liveAPI_returnsGroundedCloudInsightsNotMissingContent() async throws {
        guard let apiKey = Self.resolveLiveAPIKey() else {
            throw XCTSkip(Self.skipInstructions())
        }

        let calendar = Self.testCalendar
        let reference = Self.referenceDate
        let entries = Self.threeMeaningfulEntries(reference: reference, calendar: calendar)

        let generator = CloudReviewInsightsGenerator(
            apiKey: apiKey,
            urlSession: .shared,
            promptLanguage: .english
        )

        let insights: ReviewInsights
        do {
            insights = try await generator.generateInsights(
                from: entries,
                referenceDate: reference,
                calendar: calendar
            )
        } catch {
            XCTFail(
                """
                Live cloud insights failed: \(error).
                missingContent / invalidPayload / failedQualityGate => API output did not meet app expectations.
                """
            )
            throw error
        }

        XCTAssertEqual(insights.source, .cloudAI)
        XCTAssertFalse(
            insights.recurringGratitudes.isEmpty && insights.recurringNeeds.isEmpty && insights.recurringPeople.isEmpty,
            "Expected at least one recurring theme list from the model"
        )
        XCTAssertGreaterThan(insights.resurfacingMessage.count, 8, "resurfacingMessage should be substantive")
        XCTAssertGreaterThan(insights.continuityPrompt.count, 8, "continuityPrompt should be substantive")
        if let narrative = insights.narrativeSummary {
            XCTAssertGreaterThan(narrative.count, 8, "narrativeSummary should be substantive when present")
        }
        XCTAssertFalse(insights.weeklyInsights.isEmpty, "weeklyInsights should not be empty")
    }

    private static func threeMeaningfulEntries(reference: Date, calendar: Calendar) -> [JournalEntry] {
        let range = ReviewInsightsCloudEligibility.currentReviewPeriod(containing: reference, calendar: calendar)
        let start = range.lowerBound
        let day1 = start
        let day2 = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let day3 = calendar.date(byAdding: .day, value: 2, to: start) ?? start
        return [
            meaningfulEntry(on: day1),
            meaningfulEntry(on: day2),
            meaningfulEntry(on: day3)
        ]
    }

    private static func meaningfulEntry(on date: Date) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: [JournalItem(fullText: "Family dinner", chipLabel: "Family")],
            needs: [JournalItem(fullText: "More rest and sleep", chipLabel: "Rest")],
            people: [JournalItem(fullText: "Alex checked in", chipLabel: "Alex")]
        )
    }
}
