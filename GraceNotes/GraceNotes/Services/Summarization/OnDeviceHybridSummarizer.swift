import Foundation

/// Hybrid on-device summarizer:
/// 1) try NaturalLanguage extraction for better semantic labels
/// 2) fall back to deterministic first-N summarization when NLP confidence is low
struct OnDeviceHybridSummarizer: Summarizer {
    private let nlpSummarizer: any Summarizer
    private let deterministicSummarizer: any Summarizer

    init(
        nlpSummarizer: any Summarizer = NaturalLanguageSummarizer(),
        deterministicSummarizer: any Summarizer = DeterministicChipLabelSummarizer()
    ) {
        self.nlpSummarizer = nlpSummarizer
        self.deterministicSummarizer = deterministicSummarizer
    }

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSentence.isEmpty else {
            return SummarizationResult(label: "", isTruncated: false)
        }

        if let nlpResult = try? await nlpSummarizer.summarize(trimmedSentence, section: section),
           shouldUseNLPResult(nlpResult, originalText: trimmedSentence, section: section) {
            return nlpResult
        }

        return try await deterministicSummarizer.summarize(trimmedSentence, section: section)
    }

    private func shouldUseNLPResult(
        _ result: SummarizationResult,
        originalText: String,
        section: SummarizationSection
    ) -> Bool {
        let label = result.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return false }

        let normalizedLabel = normalize(label)
        guard !normalizedLabel.isEmpty else { return false }

        if looksLikeSectionKeywordOnly(normalizedLabel, section: section) {
            return false
        }

        if !containsHanCharacters(label), label.count < 3, originalText.count > 10 {
            return false
        }

        return true
    }

    private func looksLikeSectionKeywordOnly(_ label: String, section: SummarizationSection) -> Bool {
        let sectionKeywords: Set<String>
        switch section {
        case .gratitude:
            sectionKeywords = ["gratitude", "grateful", "thankful", "thanks", "感恩", "感谢", "感激"]
        case .need:
            sectionKeywords = ["need", "needs", "want", "wants", "需要", "想要", "想"]
        case .person:
            sectionKeywords = ["person", "people", "someone", "他", "她", "他们", "她们"]
        }

        let tokens = Set(label.split(separator: " ").map(String.init))
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { sectionKeywords.contains($0) }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsHanCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF,
                 0x2CEB0...0x2EBEF,
                 0x2F800...0x2FA1F:
                return true
            default:
                return false
            }
        }
    }
}
