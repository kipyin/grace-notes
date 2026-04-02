import XCTest
@testable import GraceNotes

final class ReviewInsightsProviderTests: XCTestCase {
    private static let testSuiteName = "ReviewInsightsProviderTests"
    private var calendar: Calendar!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        testDefaults = UserDefaults(suiteName: Self.testSuiteName)!
        testDefaults.removePersistentDomain(forName: Self.testSuiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: Self.testSuiteName)
        testDefaults = nil
        super.tearDown()
    }

    func test_generateInsights_usesDeterministicGeneratorWhenAvailable() async {
        let deterministicInsight = makeInsights(
            weeklyInsights: [weeklyInsightStub(observation: "Deterministic observation", theme: "Rest", days: 2)]
        )
        let provider = ReviewInsightsProvider(
            deterministicGenerator: StubReviewInsightsGenerator(result: .success(deterministicInsight))
        )
        let reference = date(year: 2026, month: 3, day: 18)

        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Deterministic observation")
    }

    func test_generateInsights_whenDeterministicFails_usesSparseFallbackWeekRange() async {
        let provider = ReviewInsightsProvider(
            deterministicGenerator: StubReviewInsightsGenerator(result: .failure(StubError.failed))
        )
        let referenceDate = date(year: 2026, month: 3, day: 18)

        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: referenceDate),
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weekStart, date(year: 2026, month: 3, day: 16))
        XCTAssertEqual(insights.weekEnd, date(year: 2026, month: 3, day: 23))
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            String(localized: "Start with one reflection today to build your weekly review.")
        )
    }

    func test_migrateLegacyAIFeaturesToggleIfNeeded_removesLegacyKey() {
        testDefaults.set(true, forKey: ReviewInsightsProvider.legacyAIFeaturesUserDefaultsKey)

        ReviewInsightsProvider.migrateLegacyAIFeaturesToggleIfNeeded(defaults: testDefaults)

        XCTAssertNil(testDefaults.object(forKey: ReviewInsightsProvider.legacyAIFeaturesUserDefaultsKey))
    }
}

private extension ReviewInsightsProviderTests {
    func makeInsights(weeklyInsights: [ReviewWeeklyInsight] = []) -> ReviewInsights {
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        return ReviewInsights(
            source: .deterministic,
            presentationMode: .insight,
            generatedAt: now,
            weekStart: now,
            weekEnd: now,
            weeklyInsights: weeklyInsights,
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "message",
            continuityPrompt: "prompt",
            narrativeSummary: nil,
            weekStats: sampleWeekStats()
        )
    }

    func sampleWeekStats() -> ReviewWeekStats {
        ReviewWeekStats(
            reflectionDays: 3,
            meaningfulEntryCount: 3,
            completionMix: ReviewWeekCompletionMix(
                emptyDays: 0,
                startedDays: 0,
                growingDays: 1,
                balancedDays: 2,
                fullDays: 0
            ),
            activity: [
                ReviewDayActivity(
                    date: Date(timeIntervalSince1970: 1),
                    hasReflectiveActivity: true,
                    hasPersistedEntry: true
                ),
                ReviewDayActivity(
                    date: Date(timeIntervalSince1970: 2),
                    hasReflectiveActivity: true,
                    hasPersistedEntry: true
                ),
                ReviewDayActivity(
                    date: Date(timeIntervalSince1970: 3),
                    hasReflectiveActivity: true,
                    hasPersistedEntry: true
                )
            ],
            rhythmHistory: nil,
            sectionTotals: ReviewWeekSectionTotals(
                gratitudeMentions: 3,
                needMentions: 2,
                peopleMentions: 1
            )
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

    func makeSeedEntry(on date: Date) -> Journal {
        Journal(
            entryDate: date,
            gratitudes: [Entry(fullText: "Gratitude")],
            needs: [Entry(fullText: "Need")],
            people: [Entry(fullText: "Person")]
        )
    }

    func weeklyInsightStub(observation: String, theme: String, days: Int) -> ReviewWeeklyInsight {
        ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: observation,
            action: "Action",
            primaryTheme: theme,
            mentionCount: days,
            dayCount: days
        )
    }

    func threeSeedEntriesInWeek(of referenceDate: Date) -> [Journal] {
        let range = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let start = range.lowerBound
        let day2 = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let day3 = calendar.date(byAdding: .day, value: 2, to: start) ?? start
        return [
            makeSeedEntry(on: start),
            makeSeedEntry(on: day2),
            makeSeedEntry(on: day3)
        ]
    }
}

private enum StubError: Error {
    case failed
}

private struct StubReviewInsightsGenerator: ReviewInsightsGenerating {
    let result: Result<ReviewInsights, Error>

    func generateInsights(
        from entries: [Journal],
        referenceDate: Date,
        calendar: Calendar,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) async throws -> ReviewInsights {
        _ = pastStatisticsInterval
        return try result.get()
    }
}
