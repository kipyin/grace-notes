import Foundation

@MainActor
struct JournalChipLabelSummarizationCoordinator {
    private let summarizerProvider: SummarizerProvider

    init(summarizerProvider: SummarizerProvider) {
        self.summarizerProvider = summarizerProvider
    }

    private var deterministicChipLabelSummarizer: DeterministicChipLabelSummarizer {
        DeterministicChipLabelSummarizer()
    }

    /// Shared chip-display rules for main actor and `Task.detached` paths.
    private nonisolated static func displayReadySummarizationResult(
        _ result: SummarizationResult,
        limitToChipUnits: Bool = true
    ) -> SummarizationResult {
        guard limitToChipUnits else {
            return SummarizationResult(label: result.label, isTruncated: false)
        }
        return ChipLabelUnitTruncator.displayCappedLabel(from: result.label)
    }

    func summarizeForChip(_ text: String, section: SummarizationSection) async -> SummarizationResult {
        let summarizer = summarizerProvider.currentSummarizer()
        return await Task.detached(priority: .utility) {
            do {
                let result = try await summarizer.summarize(text, section: section)
                return Self.displayReadySummarizationResult(result)
            } catch {
                let fallback = DeterministicChipLabelSummarizer().summarizeSync(text, section: section)
                return Self.displayReadySummarizationResult(fallback)
            }
        }.value
    }

    func makeInterimResult(for text: String, section: SummarizationSection) -> SummarizationResult {
        let interim = deterministicChipLabelSummarizer.summarizeSync(text, section: section)
        return Self.displayReadySummarizationResult(interim)
    }

    func makeInterimItem(fullText: String, section: SummarizationSection, id: UUID = UUID()) -> JournalItem {
        let interim = makeInterimResult(for: fullText, section: section)
        return JournalItem(
            fullText: fullText,
            chipLabel: interim.label,
            isTruncated: interim.isTruncated,
            id: id
        )
    }

    /// Display-ready label after applying chip unit rules (e.g. manual rename).
    func displayReadyManualLabel(_ result: SummarizationResult) -> SummarizationResult {
        Self.displayReadySummarizationResult(result)
    }
}
