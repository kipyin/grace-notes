import XCTest
@testable import GraceNotes

extension ReviewInsightsProviderTests {
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
}
