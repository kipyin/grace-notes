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

    /// Extracts keywords for a short chip label: prefers named entities (people, places, orgs),
    /// then nouns, verbs, adjectives. Uses nameTypeOrLexicalClass with joinNames for multi-word names.
    private func extractKeywords(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = text

        var nameTokens: [String] = []
        var lexicalTokens: [String] = []
        let range = text.startIndex..<text.endIndex
        let options: NLTagger.Options = [.joinNames, .omitPunctuation, .omitWhitespace]

        tagger.enumerateTags(in: range, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, tokenRange in
            let word = String(text[tokenRange])
            guard word.count >= minNounLength else { return true }

            if let t = tag {
                switch t {
                case .personalName, .placeName, .organizationName:
                    nameTokens.append(word)
                case .noun, .verb, .adjective:
                    lexicalTokens.append(word)
                default:
                    break
                }
            }
            return true
        }

        let keywords = nameTokens.isEmpty ? lexicalTokens : nameTokens
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
