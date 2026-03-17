import Foundation
@testable import GraceNotes

/// Tracks call count to assert summarizer was or was not invoked.
final class SpySummarizer: Summarizer {
    private(set) var summarizeCallCount = 0

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        summarizeCallCount += 1
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }
        return SummarizationResult(label: trimmed, isTruncated: false)
    }
}
