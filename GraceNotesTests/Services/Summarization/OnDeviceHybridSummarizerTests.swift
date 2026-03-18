import XCTest
@testable import GraceNotes

final class OnDeviceHybridSummarizerTests: XCTestCase {
    func test_summarize_usesNLPResult_whenHighQuality() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "Family dinner", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "Fallback label", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize("I am grateful for family dinner tonight", section: .gratitude)

        XCTAssertEqual(result.label, "Family dinner")
    }

    func test_summarize_fallsBack_whenNLPResultIsEmpty() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "First five words", isTruncated: true))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize("Need better sleep and rhythm", section: .need)

        XCTAssertEqual(result.label, "First five words")
        XCTAssertTrue(result.isTruncated)
    }

    func test_summarize_fallsBack_whenNLPResultOnlyContainsSectionKeywords() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "need", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "Better sleep", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize("I need better sleep this week", section: .need)

        XCTAssertEqual(result.label, "Better sleep")
    }

    func test_summarize_fallsBack_whenLabelTooShortForLongLatinInput() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "ok", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "Clear priorities", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize(
            "I need clearer priorities and fewer context switches",
            section: .need
        )

        XCTAssertEqual(result.label, "Clear priorities")
    }

    func test_summarize_emptyInput_returnsEmptyLabel() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "ignored", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "ignored", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize("   ", section: .gratitude)

        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_fallsBack_whenNLPThrows() async throws {
        let fallback = StubSummarizer(result: SummarizationResult(label: "Deterministic fallback", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(
            nlpSummarizer: ThrowingStubSummarizer(),
            deterministicSummarizer: fallback
        )

        let result = try await sut.summarize("Need clearer priorities today", section: .need)

        XCTAssertEqual(result.label, "Deterministic fallback")
    }

    func test_summarize_personSection_keepsShortNameFromNLP() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "Al", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "Fallback", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize("Had lunch with Al after work at the park", section: .person)

        XCTAssertEqual(result.label, "Al")
    }

    func test_summarize_needSection_keepsShortAcronymFromNLP() async throws {
        let nlp = StubSummarizer(result: SummarizationResult(label: "AI", isTruncated: false))
        let fallback = StubSummarizer(result: SummarizationResult(label: "Fallback", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(nlpSummarizer: nlp, deterministicSummarizer: fallback)

        let result = try await sut.summarize(
            "Need to reserve one focused block for AI project planning today",
            section: .need
        )

        XCTAssertEqual(result.label, "AI")
    }

    func test_summarize_rethrowsCancellationError() async {
        let fallback = StubSummarizer(result: SummarizationResult(label: "Fallback", isTruncated: false))
        let sut = OnDeviceHybridSummarizer(
            nlpSummarizer: CancelledStubSummarizer(),
            deterministicSummarizer: fallback
        )

        do {
            _ = try await sut.summarize("Need rest", section: .need)
            XCTFail("Expected cancellation error")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }
}

private struct StubSummarizer: Summarizer {
    let result: SummarizationResult

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        result
    }
}

private struct ThrowingStubSummarizer: Summarizer {
    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        throw StubSummarizerError.failed
    }
}

private struct CancelledStubSummarizer: Summarizer {
    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        throw CancellationError()
    }
}

private enum StubSummarizerError: Error {
    case failed
}
