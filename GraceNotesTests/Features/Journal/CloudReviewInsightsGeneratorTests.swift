import XCTest
@testable import GraceNotes

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
        let innerPayload = Self.sampleTypedCooccurrencePayload()

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
        XCTAssertTrue(insights.narrativeSummary?.contains("Family") == true)
        XCTAssertTrue(insights.resurfacingMessage.contains("Rest"))
        XCTAssertTrue(insights.resurfacingMessage.contains("Family"))
        XCTAssertTrue(insights.continuityPrompt.contains("Rest") || insights.continuityPrompt.contains("Family"))
        XCTAssertEqual(insights.weeklyInsights.count, 1)
        XCTAssertEqual(insights.weeklyInsights.first?.observation, insights.resurfacingMessage)
        XCTAssertEqual(insights.weeklyInsights.first?.action, insights.continuityPrompt)
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
        } catch let error as CloudReviewInsightsError {
            XCTAssertEqual(error, .invalidPayload)
        } catch {
            XCTFail("Unexpected error: \(error)")
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
        } catch let error as CloudReviewInsightsError {
            XCTAssertEqual(error, .httpError(statusCode: 500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_generateInsights_clampsMessagesAndUsesDeviceRecurringThemes() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let longTail = String(repeating: "a", count: 220)
        let longRest = "Rest" + longTail
        let longFamily = "Family" + longTail
        let manyThemes: [[String: Any]] = [
            ["label": longRest, "count": 3],
            ["label": longFamily, "count": 2],
            ["label": "Alex", "count": 2],
            ["label": "ShouldDrop", "count": 1]
        ]
        let innerPayload: [String: Any] = [
            "insightType": "cooccurrence",
            "primaryTheme": ["label": "Family", "category": "gratitudes"],
            "secondaryTheme": ["label": "Rest", "category": "needs"],
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

        XCTAssertEqual(insights.recurringGratitudes, [ReviewInsightTheme(label: "Family", count: 3)])
        XCTAssertEqual(insights.recurringNeeds, [ReviewInsightTheme(label: "Rest", count: 3)])
        XCTAssertEqual(insights.recurringPeople, [ReviewInsightTheme(label: "Alex", count: 3)])
        XCTAssertLessThanOrEqual(insights.narrativeSummary?.count ?? 0, 160)
        XCTAssertLessThanOrEqual(insights.resurfacingMessage.count, 160)
        XCTAssertLessThanOrEqual(insights.continuityPrompt.count, 160)
    }

    func test_generateInsights_parsesSnakeCaseKeysAndFlexibleCounts() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload: [String: Any] = [
            "insight_type": "cooccurrence",
            "primary_theme": ["label": "Family", "category": "gratitudes"],
            "secondary_theme": ["label": "Rest", "category": "needs"],
            "recurring_gratitudes": [["label": "Family", "count": NSNumber(value: 2.0)]],
            "recurring_needs": [["label": "Rest", "count": NSNumber(value: 3.4)]],
            "recurring_people": [["label": "Alex", "count": NSNumber(value: 2.0)]]
        ]
        setMockResponse(withInnerPayload: innerPayload)

        let insights = try await generator.generateInsights(
            from: threeMeaningfulEntriesInWeekAroundReference(),
            referenceDate: date(year: 2026, month: 3, day: 18),
            calendar: calendar
        )

        XCTAssertEqual(insights.source, .cloudAI)
        XCTAssertEqual(insights.recurringNeeds.first?.count, 3) // JSON double 3.4 rounds to 3
    }

    func test_generateInsights_parsesMarkdownFencedJSONPayload() async throws {
        let generator = CloudReviewInsightsGenerator(
            apiKey: "test-key",
            urlSession: urlSession,
            promptLanguage: .english
        )
        let innerPayload = Self.sampleTypedCooccurrencePayload()

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
        XCTAssertEqual(insights.weeklyInsights.first?.observation, insights.resurfacingMessage)
        XCTAssertEqual(insights.weeklyInsights.first?.action, insights.continuityPrompt)
    }
}

private extension CloudReviewInsightsGeneratorTests {
    static func sampleTypedCooccurrencePayload() -> [String: Any] {
        [
            "insightType": "cooccurrence",
            "primaryTheme": ["label": "Family", "category": "gratitudes"],
            "secondaryTheme": ["label": "Rest", "category": "needs"],
            "recurringGratitudes": [["label": "Family", "count": 2]],
            "recurringNeeds": [["label": "Rest", "count": 3]],
            "recurringPeople": [["label": "Alex", "count": 2]]
        ]
    }

    func normalizedInsightLine(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: Locale.current)
            .lowercased()
    }

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
          "insightType": "dominantCategory",
          "primaryTheme": {"label":"Rest","category":"needs"},
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
