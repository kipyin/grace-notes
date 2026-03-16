import Foundation
import NaturalLanguage

/// Summarizes a sentence into a short chip label using on-device NL.
/// Falls back to first N words when keyword extraction returns nothing useful.
struct NaturalLanguageSummarizer: Summarizer {
    private let maxFallbackWords = 5
    private let minNounLength = 2

    func summarize(_ sentence: String) -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        if let label = extractKeywords(from: trimmed), !label.isEmpty {
            return SummarizationResult(label: label, isTruncated: false)
        }
        return firstNWords(from: trimmed)
    }

    /// Extracts keywords (nouns, verbs, adjectives) for a short chip label.
    private func extractKeywords(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var keywords: [String] = []
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if tag == .noun || tag == .verb || tag == .adjective {
                let word = String(text[tokenRange])
                if word.count >= minNounLength {
                    keywords.append(word)
                }
            }
            return true
        }

        guard !keywords.isEmpty else { return nil }
        return keywords.prefix(3).joined(separator: " ")
    }

    private func firstNWords(from text: String) -> SummarizationResult {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var words: [String] = []
        let range = text.startIndex..<text.endIndex
        let skipArticles = Set(["a", "an", "the"])

        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let word = String(text[tokenRange]).lowercased()
            if !skipArticles.contains(word) {
                words.append(String(text[tokenRange]))
            }
            return true
        }

        let take = min(words.count, maxFallbackWords)
        guard take > 0 else {
            let fallback = firstTokensUpToMaxChars(text, maxChars: 20)
            return SummarizationResult(label: fallback, isTruncated: true)
        }

        let label = words.prefix(take).joined(separator: " ")
        return SummarizationResult(label: label, isTruncated: words.count > maxFallbackWords)
    }

    private func firstTokensUpToMaxChars(_ text: String, maxChars: Int) -> String {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        var len = 0
        let range = text.startIndex..<text.endIndex
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let word = String(text[tokenRange])
            let addLen = tokens.isEmpty ? word.count : 1 + word.count
            if len + addLen <= maxChars {
                tokens.append(word)
                len += addLen
                return true
            }
            return false
        }
        return tokens.isEmpty ? String(text.prefix(maxChars)) : tokens.joined(separator: " ")
    }
}
