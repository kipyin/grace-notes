import Foundation

/// On-device chip label source: trimmed full entry text. When cloud summarization is off, the view model
/// applies `ChipLabelUnitTruncator.displayCappedLabel` for length and trailing `...`.
struct DeterministicChipLabelSummarizer: Summarizer {
    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        label(from: sentence)
    }

    func summarizeSync(_ sentence: String, section _: SummarizationSection) -> SummarizationResult {
        label(from: sentence)
    }

    private func label(from sentence: String) -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SummarizationResult(label: "", isTruncated: false)
        }
        return SummarizationResult(label: trimmed, isTruncated: false)
    }
}
