import XCTest
@testable import GraceNotes

extension CloudReviewInsightsGeneratorTests {
    func test_generateInsights_invalidContrastCategories_throwsQualityGate() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "insightType": "contrast",
            "primaryTheme": ["label": "Family", "category": "gratitudes"],
            "secondaryTheme": ["label": "Alex", "category": "people"],
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": [["label": "Alex", "count": 2]]
        ]
        setMockResponse(withInnerPayload: innerPayload)

        do {
            _ = try await generator.generateInsights(
                from: threeMeaningfulEntriesInWeekAroundReference(),
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected quality gate failure")
        } catch let error as CloudReviewInsightsError {
            XCTAssertEqual(error, .failedQualityGate)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_generateInsights_missingPrimaryLabelInRecurringList_throwsQualityGate() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "insightType": "cooccurrence",
            "primaryTheme": ["label": "Missing", "category": "gratitudes"],
            "secondaryTheme": ["label": "Rest", "category": "needs"],
            "recurringGratitudes": [],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": [["label": "Alex", "count": 2]]
        ]
        setMockResponse(withInnerPayload: innerPayload)

        do {
            _ = try await generator.generateInsights(
                from: threeMeaningfulEntriesInWeekAroundReference(),
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected quality gate failure")
        } catch let error as CloudReviewInsightsError {
            XCTAssertEqual(error, .failedQualityGate)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_generateInsights_temporalShiftWithWeakEvidenceDays_throwsQualityGate() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "insightType": "temporalShift",
            "primaryTheme": ["label": "Rest", "category": "needs"],
            "evidenceDays": 1,
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": [["label": "Alex", "count": 2]]
        ]
        setMockResponse(withInnerPayload: innerPayload)

        do {
            _ = try await generator.generateInsights(
                from: threeMeaningfulEntriesInWeekAroundReference(),
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected quality gate failure")
        } catch let error as CloudReviewInsightsError {
            XCTAssertEqual(error, .failedQualityGate)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_generateInsights_dominantCategory_rendersGroundedChain() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "insightType": "dominantCategory",
            "primaryTheme": ["label": "Rest", "category": "needs"],
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": [["label": "Alex", "count": 2]]
        ]
        setMockResponse(withInnerPayload: innerPayload)

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertTrue(insights.resurfacingMessage.contains("Rest"))
        XCTAssertTrue(insights.narrativeSummary?.contains("Rest") == true)
        XCTAssertTrue(insights.continuityPrompt.contains("Rest"))
    }

    func test_generateInsights_cooccurrence_narrativeIsDistinctFromObservation() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        setMockResponse(withInnerPayload: Self.sampleTypedCooccurrencePayload())

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        let observation = insights.resurfacingMessage
        let narrative = insights.narrativeSummary ?? ""
        XCTAssertFalse(narrative.isEmpty)
        XCTAssertNotEqual(normalizedInsightLine(narrative), normalizedInsightLine(observation))
        XCTAssertTrue(narrative.lowercased().contains("alongside"))
    }

    func test_generateInsights_requestPrompt_includesInsightQualityRules() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let requestCapture = makePromptCaptureMock()

        _ = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )
        await fulfillment(of: [requestCapture.expectation], timeout: 1.0)

        guard let capturedRequestBody = requestCapture.getBody() else {
            XCTFail("Expected request body to be captured")
            return
        }
        let requestObject = try JSONSerialization.jsonObject(with: capturedRequestBody)
        guard let requestDict = requestObject as? [String: Any],
              let messages = requestDict["messages"] as? [[String: Any]],
              let prompt = messages.first?["content"] as? String
        else {
            return XCTFail("Expected prompt content in request")
        }

        XCTAssertTrue(prompt.contains("insightType"))
        XCTAssertTrue(prompt.contains("cooccurrence"))
        XCTAssertTrue(prompt.contains("Do not output narrativeSummary"))
        XCTAssertTrue(prompt.contains("personThemePairing"))
    }

    func test_generateInsights_requestPrompt_usesSimplifiedChineseWhenPromptLanguageZhHans() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .simplifiedChinese
        )
        let requestCapture = makePromptCaptureMock()

        _ = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )
        await fulfillment(of: [requestCapture.expectation], timeout: 1.0)

        guard let capturedRequestBody = requestCapture.getBody() else {
            XCTFail("Expected request body to be captured")
            return
        }
        let requestObject = try JSONSerialization.jsonObject(with: capturedRequestBody)
        guard let requestDict = requestObject as? [String: Any],
              let messages = requestDict["messages"] as? [[String: Any]],
              let prompt = messages.first?["content"] as? String
        else {
            return XCTFail("Expected prompt content in request")
        }

        XCTAssertTrue(prompt.contains("下方是最近七天的记录"))
        XCTAssertTrue(prompt.contains("只输出合法 JSON"))
        XCTAssertTrue(prompt.contains("insightType"))
        XCTAssertTrue(prompt.contains("不要"))
    }

    func test_generateInsights_withoutMeaningfulCurrentWeekEntries_throwsBeforeAPICall() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        var didCallAPI = false
        MockURLProtocol.mockResponse = { _ in
            didCallAPI = true
            let http = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), http, nil)
        }

        let blankCurrentWeekEntry = JournalEntry(entryDate: date(year: 2026, month: 3, day: 18))
        let previousWeekEntry = JournalEntry(
            entryDate: date(year: 2026, month: 3, day: 10),
            gratitudes: [JournalItem(fullText: "Family", chipLabel: "Family")]
        )

        do {
            _ = try await generator.generateInsights(
                from: [blankCurrentWeekEntry, previousWeekEntry],
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected insufficient context error")
        } catch {
            XCTAssertFalse(didCallAPI)
        }
    }

    func test_generateInsights_twoMeaningfulEntries_throwsBeforeAPICall() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        var didCallAPI = false
        MockURLProtocol.mockResponse = { _ in
            didCallAPI = true
            let http = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), http, nil)
        }

        let first = makeEntry(on: date(year: 2026, month: 3, day: 17))
        let second = makeEntry(on: date(year: 2026, month: 3, day: 18))

        do {
            _ = try await generator.generateInsights(
                from: [first, second],
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected insufficient context error")
        } catch {
            XCTAssertFalse(didCallAPI)
        }
    }

    func test_generateInsights_ignoresCloudRecurringListsWhenDeviceThemesExist() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "insightType": "dominantCategory",
            "primaryTheme": ["label": "Rest", "category": "needs"],
            "recurringGratitudes": [],
            "recurringNeeds": [],
            "recurringPeople": []
        ]
        setMockResponse(withInnerPayload: innerPayload)

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringGratitudes, [ReviewInsightTheme(label: "Family", count: 3)])
        XCTAssertEqual(insights.recurringNeeds, [ReviewInsightTheme(label: "Rest", count: 3)])
        XCTAssertEqual(insights.recurringPeople, [ReviewInsightTheme(label: "Alex", count: 3)])
        XCTAssertTrue(insights.resurfacingMessage.contains("Rest"))
    }

}
