import Foundation
@testable import FiveCubedMoments

/// Returns input as label for predictable tests.
final class MockSummarizer: Summarizer {
    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }
        return SummarizationResult(label: trimmed, isTruncated: false)
    }
}
