import XCTest
@testable import GraceNotes

final class CloudSummarizerPromptAndGroundingTests: XCTestCase {
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

    func test_summarize_englishPrompt_embedsInstructionAndUserText() async throws {
        var capturedPrompt: String?
        MockURLProtocol.mockResponse = { request in
            capturedPrompt = CloudSummarizerTestSupport.chatPrompt(from: request)
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": "Family"]]
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
            urlSession: urlSession,
            promptLanguage: .english
        )

        _ = try await summarizer.summarize("I love my family", section: .gratitude)

        let prompt = try XCTUnwrap(capturedPrompt)
        XCTAssertTrue(prompt.contains("Extract"), "English chip prompt should use English instructions")
        XCTAssertTrue(prompt.contains("I love my family"))
    }

    func test_summarize_simplifiedChinesePrompt_embedsUserTextMarker() async throws {
        var capturedPrompt: String?
        MockURLProtocol.mockResponse = { request in
            capturedPrompt = CloudSummarizerTestSupport.chatPrompt(from: request)
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": "妈妈"]]
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
            urlSession: urlSession,
            promptLanguage: .simplifiedChinese
        )

        _ = try await summarizer.summarize("谢谢妈妈", section: .gratitude)

        let prompt = try XCTUnwrap(capturedPrompt)
        XCTAssertTrue(prompt.contains("用户原文："), "zh-Hans chip prompt should use Chinese instructions")
        XCTAssertTrue(prompt.contains("谢谢妈妈"))
    }

    func test_summarize_lowSignalLatinMash_skipsNetworkUsesFallback() async throws {
        var apiCallCount = 0
        MockURLProtocol.mockResponse = { _ in
            apiCallCount += 1
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": "should not run"]]
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
            urlSession: urlSession,
            promptLanguage: .english
        )

        let gibberish = "aksdjlfksjdlfkjs"
        let result = try await summarizer.summarize(gibberish, section: .gratitude)

        XCTAssertEqual(apiCallCount, 0, "Low-signal input should not hit the cloud API")
        XCTAssertEqual(result.label, gibberish)
        XCTAssertEqual(mockFallback.summarizeCallCount, 1)
    }

    func test_summarize_ungroundedGenericChineseResponse_usesFallback() async throws {
        MockURLProtocol.mockResponse = { _ in
            let json: [String: Any] = [
                "choices": [
                    ["message": ["content": "心存感激"]]
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
            urlSession: urlSession,
            promptLanguage: .english
        )

        let entry = "hello world"
        let result = try await summarizer.summarize(entry, section: .gratitude)

        XCTAssertEqual(result.label, entry)
        XCTAssertGreaterThanOrEqual(mockFallback.summarizeCallCount, 1)
    }
}
