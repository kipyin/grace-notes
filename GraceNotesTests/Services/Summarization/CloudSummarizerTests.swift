import XCTest
@testable import GraceNotes

final class CloudSummarizerTests: XCTestCase {
    private var urlSession: URLSession!
    private var mockFallback: MockSummarizer!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: config)
        mockFallback = MockSummarizer()
    }

    override func tearDown() {
        MockURLProtocol.mockResponse = nil
        super.tearDown()
    }

    func test_summarize_emptyString_returnsEmptyLabel() async throws {
        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("", section: .gratitude)

        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_whitespaceOnly_returnsEmptyLabel() async throws {
        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("   \n  ", section: .gratitude)

        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_successPath_returnsAPILabel() async throws {
        MockURLProtocol.mockResponse = { _ in
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": "Family love"]]
                ]
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: json) else {
                return (nil, nil, NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "bad json"]))
            }
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response, nil)
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("I am grateful for my family", section: .gratitude)

        XCTAssertEqual(result.label, "Family love")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_successPath_longLabel_truncatesWithIsTruncatedTrue() async throws {
        let longLabel = String(repeating: "a", count: 25)
        MockURLProtocol.mockResponse = { _ in
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": longLabel]]
                ]
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: json) else {
                return (nil, nil, NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "bad json"]))
            }
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response, nil)
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("Long input", section: .gratitude)

        XCTAssertEqual(result.label.count, 10)
        XCTAssertTrue(result.isTruncated)
    }

    func test_summarize_httpError_fallsBackToInjectedFallback() async throws {
        MockURLProtocol.mockResponse = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response, nil)
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("Family", section: .gratitude)

        XCTAssertEqual(result.label, "Family", "MockSummarizer returns input as label")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_invalidJSON_fallsBackToInjectedFallback() async throws {
        MockURLProtocol.mockResponse = { _ in
            let data = Data("not valid json".utf8)
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response, nil)
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("Peace", section: .need)

        XCTAssertEqual(result.label, "Peace")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_emptyContent_fallsBackToInjectedFallback() async throws {
        MockURLProtocol.mockResponse = { _ in
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": "   "] as [String: Any]]
                ]
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: json) else {
                return (nil, nil, NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "bad json"]))
            }
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response, nil)
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("Wisdom", section: .need)

        XCTAssertEqual(result.label, "Wisdom")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_networkError_fallsBackToInjectedFallback() async throws {
        MockURLProtocol.mockResponse = { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            fallback: mockFallback,
            urlSession: urlSession
        )

        let result = try await summarizer.summarize("Alice", section: .person)

        XCTAssertEqual(result.label, "Alice")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_networkError_withDefaultFallback_usesDeterministicFallback() async throws {
        MockURLProtocol.mockResponse = { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }

        let summarizer = CloudSummarizer(
            apiKey: "test-key",
            urlSession: urlSession
        )

        let input = "Extraordinary opportunities for collaboration"
        let result = try await summarizer.summarize(input, section: .need)

        XCTAssertEqual(result.label, String(input.prefix(10)))
        XCTAssertTrue(result.isTruncated)
    }
}
