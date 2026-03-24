import XCTest
@testable import GraceNotes

// swiftlint:disable type_body_length
final class CloudReviewInsightsGeneratorTests: XCTestCase {
    private var urlSession: URLSession!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        urlSession = URLSession(configuration: config)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        MockURLProtocol.mockResponse = nil
    }

    override func tearDown() {
        MockURLProtocol.mockResponse = nil
        super.tearDown()
    }

    func test_generateInsights_success_returnsCloudInsights() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "narrativeSummary": "You kept a calm rhythm this week.",
            "resurfacingMessage": "You mentioned rest 3 times this week.",
            "continuityPrompt": "What can protect your rest tomorrow?",
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

        XCTAssertEqual(insights.source, .cloudAI)
        XCTAssertEqual(insights.recurringNeeds.first?.label, "Rest")
        XCTAssertEqual(insights.recurringNeeds.first?.count, 3)
        XCTAssertTrue(insights.narrativeSummary?.contains("Rest") == true)
        XCTAssertEqual(insights.weeklyInsights.count, 1)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "You mentioned rest 3 times this week.")
        XCTAssertEqual(insights.weeklyInsights.first?.action, "What can protect your rest tomorrow?")
    }

    func test_generateInsights_invalidPayload_throws() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )

        MockURLProtocol.mockResponse = { _ in
            let response: [String: Any] = [
                "choices": [["message": ["content": "not-json"]]]
            ]
            let data: Data
            do {
                data = try JSONSerialization.data(withJSONObject: response)
            } catch {
                return (nil, nil, error)
            }
            let http = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, http, nil)
        }

        do {
            _ = try await generator.generateInsights(
                from: threeMeaningfulEntriesInWeekAroundReference(),
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected invalid payload error")
        } catch let error as NSError {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    /// OpenAI-style 200 with no completion choices → `missingContent` (distinct from empty journal context).
    func test_generateInsights_emptyChoices_throwsMissingContent() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )

        MockURLProtocol.mockResponse = { _ in
            let response: [String: Any] = ["choices": []]
            let data: Data
            do {
                data = try JSONSerialization.data(withJSONObject: response)
            } catch {
                return (nil, nil, error)
            }
            let http = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, http, nil)
        }

        do {
            _ = try await generator.generateInsights(
                from: threeMeaningfulEntriesInWeekAroundReference(),
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected missingContent")
        } catch let error as CloudReviewInsightsError {
            XCTAssertEqual(error, .missingContent)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_generateInsights_httpError_throws() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )

        MockURLProtocol.mockResponse = { _ in
            let http = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), http, nil)
        }

        do {
            _ = try await generator.generateInsights(
                from: threeMeaningfulEntriesInWeekAroundReference(),
                referenceDate: date(year: 2026, month: 3, day: 18),
                calendar: calendar
            )
            XCTFail("Expected HTTP error")
        } catch let error as NSError {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func test_generateInsights_clampsMessagesAndThemeLists() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let longTail = String(repeating: "a", count: 220)
        // Leading theme tokens keep post-clamp copy grounded for validateGroundedQuality.
        let longMessage = "Rest and Family " + longTail
        let manyThemes: [[String: Any]] = [
            ["label": "Rest", "count": 3],
            ["label": "Family", "count": 2],
            ["label": "Alex", "count": 2],
            ["label": "ShouldDrop", "count": 1]
        ]
        let innerPayload: [String: Any] = [
            "narrativeSummary": longMessage,
            "resurfacingMessage": longMessage,
            "continuityPrompt": "What one step would protect Rest tomorrow? " + longTail,
            "recurringGratitudes": manyThemes,
            "recurringNeeds": manyThemes,
            "recurringPeople": manyThemes
        ]

        setMockResponse(withInnerPayload: innerPayload)

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringGratitudes.count, 3)
        XCTAssertEqual(insights.recurringNeeds.count, 3)
        XCTAssertEqual(insights.recurringPeople.count, 3)
        XCTAssertLessThanOrEqual(insights.narrativeSummary?.count ?? 0, 160)
        XCTAssertLessThanOrEqual(insights.resurfacingMessage.count, 160)
        XCTAssertLessThanOrEqual(insights.continuityPrompt.count, 160)
    }

    func test_generateInsights_parsesMarkdownFencedJSONPayload() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "narrativeSummary": "This week you reflected on Rest and Family.",
            "resurfacingMessage": "You mentioned Rest 2 times this week.",
            "continuityPrompt": "What can protect your Rest tomorrow?",
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 2]],
            "recurringPeople": []
        ]

        let contentData = try JSONSerialization.data(withJSONObject: innerPayload)
        let content = String(data: contentData, encoding: .utf8) ?? "{}"
        setMockResponse(withRawContent: "```json\n\(content)\n```")

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringNeeds.first?.label, "Rest")
        XCTAssertTrue(insights.continuityPrompt.contains("Rest"))
        XCTAssertEqual(insights.weeklyInsights.first?.observation, "You mentioned Rest 2 times this week.")
        XCTAssertEqual(insights.weeklyInsights.first?.action, "What can protect your Rest tomorrow?")
    }

    func test_generateInsights_genericContinuityPrompt_isReplacedWithThemePrompt() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "narrativeSummary": "You kept a calm rhythm this week.",
            "resurfacingMessage": "You mentioned Rest 3 times this week.",
            "continuityPrompt": "Take it one day at a time.",
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": []
        ]

        setMockResponse(withInnerPayload: innerPayload)

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertTrue(insights.continuityPrompt.contains("Rest"))
        XCTAssertFalse(insights.continuityPrompt.contains("one day at a time"))
    }

    func test_generateInsights_themeLessNarrative_isReplacedWithThemeGroundedNarrative() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "narrativeSummary": "You kept a calm rhythm this week.",
            "resurfacingMessage": "You mentioned Rest 3 times this week.",
            "continuityPrompt": "What can protect your Rest tomorrow?",
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": []
        ]

        setMockResponse(withInnerPayload: innerPayload)

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertTrue(insights.narrativeSummary?.contains("Rest") == true)
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

        XCTAssertTrue(prompt.contains("Ground messages in the provided seven-day context"))
        XCTAssertTrue(prompt.contains("continuityPrompt must be a specific follow-up question"))
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

    func test_generateInsights_emptyRecurringListsAfterSanitize_failsQualityGate() async {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "narrativeSummary": "You kept a calm rhythm this week.",
            "resurfacingMessage": "You mentioned rest 3 times this week.",
            "continuityPrompt": "What can protect your rest tomorrow?",
            "recurringGratitudes": [],
            "recurringNeeds": [],
            "recurringPeople": []
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
            XCTAssertEqual(error, CloudReviewInsightsError.failedQualityGate)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

}

private extension CloudReviewInsightsGeneratorTests {
    /// Three seed+ journal rows in the seven-day review period ending 2026-03-18 (Mar 12–18).
    func threeMeaningfulEntriesInWeekAroundReference() -> [JournalEntry] {
        [
            makeEntry(on: date(year: 2026, month: 3, day: 16)),
            makeEntry(on: date(year: 2026, month: 3, day: 17)),
            makeEntry(on: date(year: 2026, month: 3, day: 18))
        ]
    }

    func makeEntry(on date: Date) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: [JournalItem(fullText: "Family", chipLabel: "Family")],
            needs: [JournalItem(fullText: "Rest", chipLabel: "Rest")],
            people: [JournalItem(fullText: "Alex", chipLabel: "Alex")]
        )
    }

    func setMockResponse(withInnerPayload innerPayload: [String: Any]) {
        MockURLProtocol.mockResponse = { _ in
            let contentData: Data
            do {
                contentData = try JSONSerialization.data(withJSONObject: innerPayload)
            } catch {
                return (nil, nil, error)
            }
            let content = String(data: contentData, encoding: .utf8) ?? "{}"
            return self.makeMockAPIResponse(content: content)
        }
    }

    func setMockResponse(withRawContent content: String) {
        MockURLProtocol.mockResponse = { _ in
            self.makeMockAPIResponse(content: content)
        }
    }

    // swiftlint:disable:next large_tuple
    func makeMockAPIResponse(content: String) -> (Data?, HTTPURLResponse?, Error?) {
        let response: [String: Any] = [
            "choices": [["message": ["content": content]]]
        ]
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: response)
        } catch {
            return (nil, nil, error)
        }
        let http = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, http, nil)
    }

    func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    func requestBody(from request: URLRequest) -> Data? {
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                return nil
            }
            if bytesRead == 0 {
                break
            }
            data.append(buffer, count: bytesRead)
        }

        return data.isEmpty ? nil : data
    }

    func makePromptCaptureMock() -> (expectation: XCTestExpectation, getBody: () -> Data?) {
        var capturedRequestBody: Data?
        let requestCaptured = expectation(description: "Cloud request body captured")
        let content = """
        {
          "narrativeSummary": "You reflected on Rest.",
          "resurfacingMessage": "You mentioned Rest 2 times this week.",
          "continuityPrompt": "What can protect your Rest tomorrow?",
          "recurringGratitudes": [],
          "recurringNeeds": [{"label":"Rest","count":2}],
          "recurringPeople": []
        }
        """
        MockURLProtocol.mockResponse = { request in
            capturedRequestBody = request.httpBody ?? self.requestBody(from: request)
            requestCaptured.fulfill()
            return self.makeMockAPIResponse(content: content)
        }
        return (requestCaptured, { capturedRequestBody })
    }
}
// swiftlint:enable type_body_length
