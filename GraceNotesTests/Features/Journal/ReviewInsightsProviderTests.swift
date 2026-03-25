import XCTest
@testable import GraceNotes

// swiftlint:disable type_body_length
final class ReviewInsightsProviderTests: XCTestCase {
    private static let legacyAIReviewInsightsKey = "useAIReviewInsights"
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

    func test_generateInsights_aiEnabled_skipsCloudWhenFewerThanThreeMeaningfulEntriesInWeek() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloudInsight = weeklyInsightStub(observation: "Cloud observation", theme: "Rest", days: 3)
        let deterministicInsight = weeklyInsightStub(
            observation: "Deterministic observation",
            theme: "Rest",
            days: 2
        )
        let provider = ReviewInsightsProvider(
            deterministicGenerator: StubReviewInsightsGenerator(
                result: .success(makeInsights(source: .deterministic, weeklyInsights: [deterministicInsight]))
            ),
            cloudGenerator: StubReviewInsightsGenerator(
                result: .success(makeInsights(source: .cloudAI, weeklyInsights: [cloudInsight]))
            ),
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let entries = [makeSeedEntry(on: date(year: 2026, month: 3, day: 17)), makeSeedEntry(on: reference)]

        let insights = await provider.generateInsights(from: entries, referenceDate: reference, calendar: calendar)

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Deterministic observation")
        XCTAssertEqual(insights.cloudSkippedReason, .insufficientEvidenceThisWeek)
    }

    func test_generateInsights_aiEnabled_returnsCloudInsightsWhenAvailable() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(
            result: .success(
                makeInsights(
                    source: .cloudAI,
                    weeklyInsights: [
                        ReviewWeeklyInsight(
                            pattern: .recurringTheme,
                            observation: "Cloud observation",
                            action: "Cloud action",
                            primaryTheme: "Rest",
                            mentionCount: 3,
                            dayCount: 2
                        )
                    ]
                )
            )
        )
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )

        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .cloudAI)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Cloud observation")
        XCTAssertNil(insights.cloudSkippedReason)
    }

    func test_generateInsights_cloudStatsFirstFallsBackToDeterministic() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(
            result: .success(
                makeInsights(
                    source: .cloudAI,
                    weeklyInsights: [
                        ReviewWeeklyInsight(
                            pattern: .recurringTheme,
                            observation: "Cloud observation",
                            action: "Cloud action",
                            primaryTheme: "Rest",
                            mentionCount: 1,
                            dayCount: 1
                        )
                    ]
                ).withPresentationMode(.statsFirst)
            )
        )
        let deterministic = StubReviewInsightsGenerator(
            result: .success(
                makeInsights(
                    source: .deterministic,
                    weeklyInsights: [
                        weeklyInsightStub(
                            observation: "Deterministic observation",
                            theme: "Rest",
                            days: 2
                        )
                    ]
                )
            )
        )
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )

        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Deterministic observation")
        XCTAssertEqual(insights.cloudSkippedReason, .insufficientPatternSignalThisWeek)
    }

    func test_generateInsights_aiDisabled_usesDeterministicInsights() async {
        testDefaults.set(false, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .success(makeInsights(source: .cloudAI)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )

        let insights = await provider.generateInsights(
            from: [],
            referenceDate: Date(timeIntervalSince1970: 1_742_147_200),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertNil(insights.cloudSkippedReason)
    }

    func test_generateInsights_aiFailure_fallsBackToDeterministicInsights() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let deterministic = StubReviewInsightsGenerator(
            result: .success(
                makeInsights(
                    source: .deterministic,
                    weeklyInsights: [
                        ReviewWeeklyInsight(
                            pattern: .recurringTheme,
                            observation: "Deterministic observation",
                            action: "Deterministic action",
                            primaryTheme: "Rest",
                            mentionCount: 2,
                            dayCount: 2
                        )
                    ]
                )
            )
        )
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )

        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "Deterministic observation")
        XCTAssertEqual(insights.cloudSkippedReason, .cloudGenerationFailed)
    }

    func test_generateInsights_whenBothGeneratorsFail_usesWeekRangeFallback() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let deterministic = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let expectedWeekStart = date(year: 2026, month: 3, day: 12)
        let expectedWeekEnd = date(year: 2026, month: 3, day: 19)

        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: referenceDate),
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weekStart, expectedWeekStart)
        XCTAssertEqual(insights.weekEnd, expectedWeekEnd)
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            "Start with one reflection today to build your weekly review."
        )
        XCTAssertEqual(
            insights.weeklyInsights.first?.action,
            "What feels most important to carry into next week?"
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudGenerationFailed)
    }

    func test_generateInsights_aiEnabled_withoutCurrentWeekContent_returnsDeterministicStarterInsight() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(StubError.failed))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: DeterministicReviewInsightsGenerator(),
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let previousWeekEntry = JournalEntry(
            entryDate: date(year: 2026, month: 3, day: 10),
            gratitudes: [JournalItem(fullText: "Family", chipLabel: "Family")]
        )

        let insights = await provider.generateInsights(
            from: [previousWeekEntry],
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.weeklyInsights.first?.pattern, .sparseFallback)
        XCTAssertEqual(
            insights.weeklyInsights.first?.observation,
            "Start with one reflection today to build your weekly review."
        )
        XCTAssertEqual(insights.cloudSkippedReason, .insufficientEvidenceThisWeek)
    }

    func test_generateInsights_cloudHTTP503_mapsToServiceTemporarilyUnavailable() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.httpError(statusCode: 503)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudServiceTemporarilyUnavailable)
    }

    func test_generateInsights_cloudHTTP401_mapsToAuthOrQuota() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.httpError(statusCode: 401)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudServiceAuthOrQuota)
    }

    func test_generateInsights_cloudHTTP408_mapsToRequestTimedOut() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.httpError(statusCode: 408)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudRequestTimedOut)
    }

    func test_generateInsights_cloudHTTP404_mapsToResponseNotUsable() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.httpError(statusCode: 404)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudResponseNotUsable)
    }

    func test_generateInsights_cloudQualityGate_mapsToQualityCheckFailed() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.failedQualityGate))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudInsightQualityCheckFailed)
    }

    func test_generateInsights_cloudInvalidPayload_mapsToResponseNotUsable() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.invalidPayload))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudResponseNotUsable)
    }

    func test_generateInsights_cloudInsufficientContext_mapsToInsufficientEvidence() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(CloudReviewInsightsError.insufficientContext))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .insufficientEvidenceThisWeek)
    }

    func test_generateInsights_URLErrorNotConnected_mapsToNetworkUnavailable() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(URLError(.notConnectedToInternet)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudNetworkUnavailable)
    }

    func test_generateInsights_URLErrorTimedOut_mapsToRequestTimedOut() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let cloud = StubReviewInsightsGenerator(result: .failure(URLError(.timedOut)))
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: cloud,
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )
        XCTAssertEqual(insights.cloudSkippedReason, .cloudRequestTimedOut)
    }

    func test_generateInsights_aiEnabled_cloudGeneratorUnavailable_setsMisconfiguredReason() async {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        let deterministic = StubReviewInsightsGenerator(result: .success(makeInsights(source: .deterministic)))
        let provider = ReviewInsightsProvider(
            deterministicGenerator: deterministic,
            cloudGenerator: nil,
            apiKey: "",
            userDefaults: testDefaults
        )
        let reference = date(year: 2026, month: 3, day: 18)
        let insights = await provider.generateInsights(
            from: threeSeedEntriesInWeek(of: reference),
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .deterministic)
        XCTAssertEqual(insights.cloudSkippedReason, .cloudMisconfigured)
    }

    func test_migrateLegacyAIFeaturesToggle_whenLegacyTrue_setsUnifiedKeyAndClearsLegacy() {
        testDefaults.set(true, forKey: Self.legacyAIReviewInsightsKey)
        testDefaults.removeObject(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)

        ReviewInsightsProvider.migrateLegacyAIFeaturesToggleIfNeeded(defaults: testDefaults)

        let unifiedValue = testDefaults.object(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey) as? Bool
        let legacyValue = testDefaults.object(forKey: Self.legacyAIReviewInsightsKey) as? Bool
        XCTAssertEqual(unifiedValue, true)
        XCTAssertNil(legacyValue)
    }

    func test_migrateLegacyAIFeaturesToggle_whenUnifiedAlreadyTrue_keepsTrue() {
        testDefaults.set(true, forKey: ReviewInsightsProvider.aiFeaturesEnabledKey)
        testDefaults.set(false, forKey: Self.legacyAIReviewInsightsKey)

        ReviewInsightsProvider.migrateLegacyAIFeaturesToggleIfNeeded(defaults: testDefaults)

        let unifiedValue = testDefaults.object(forKey: ReviewInsightsProvider.aiFeaturesEnabledKey) as? Bool
        XCTAssertEqual(unifiedValue, true)
    }

    private func makeInsights(
        source: ReviewInsightSource,
        weeklyInsights: [ReviewWeeklyInsight] = []
    ) -> ReviewInsights {
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        return ReviewInsights(
            source: source,
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
            weekStats: sampleWeekStats(),
            cloudSkippedReason: nil
        )
    }

    private func sampleWeekStats() -> ReviewWeekStats {
        ReviewWeekStats(
            reflectionDays: 3,
            meaningfulEntryCount: 3,
            completionMix: ReviewWeekCompletionMix(
                soilDays: 0,
                seedDays: 0,
                ripeningDays: 1,
                harvestDays: 2,
                abundanceDays: 0
            ),
            activity: [
                ReviewDayActivity(date: Date(timeIntervalSince1970: 1), hasMeaningfulContent: true),
                ReviewDayActivity(date: Date(timeIntervalSince1970: 2), hasMeaningfulContent: true),
                ReviewDayActivity(date: Date(timeIntervalSince1970: 3), hasMeaningfulContent: true)
            ],
            sectionTotals: ReviewWeekSectionTotals(
                gratitudeMentions: 3,
                needMentions: 2,
                peopleMentions: 1
            )
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

    private func makeSeedEntry(on date: Date) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: [JournalItem(fullText: "Gratitude", chipLabel: "Gratitude")],
            needs: [JournalItem(fullText: "Need", chipLabel: "Need")],
            people: [JournalItem(fullText: "Person", chipLabel: "Person")]
        )
    }

    private func weeklyInsightStub(observation: String, theme: String, days: Int) -> ReviewWeeklyInsight {
        ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: observation,
            action: "Action",
            primaryTheme: theme,
            mentionCount: days,
            dayCount: days
        )
    }

    private func threeSeedEntriesInWeek(of referenceDate: Date) -> [JournalEntry] {
        let range = ReviewInsightsCloudEligibility.currentReviewPeriod(
            containing: referenceDate,
            calendar: calendar
        )
        let start = range.lowerBound
        let day1 = start
        let day2 = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let day3 = calendar.date(byAdding: .day, value: 2, to: start) ?? start
        return [
            makeSeedEntry(on: day1),
            makeSeedEntry(on: day2),
            makeSeedEntry(on: day3)
        ]
    }
}

// swiftlint:enable type_body_length

private enum StubError: Error {
    case failed
}

private struct StubReviewInsightsGenerator: ReviewInsightsGenerating {
    let result: Result<ReviewInsights, Error>

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> ReviewInsights {
        try result.get()
    }
}
