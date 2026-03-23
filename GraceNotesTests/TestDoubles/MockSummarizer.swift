import Foundation
@testable import GraceNotes

/// Returns input as label for predictable tests.
final class MockSummarizer: Summarizer {
    private(set) var summarizeCallCount = 0

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        summarizeCallCount += 1
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }
        return SummarizationResult(label: trimmed, isTruncated: false)
    }
}
