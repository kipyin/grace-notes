import Foundation
import NaturalLanguage

/// Summarizes a sentence into a short chip label using on-device NL.
/// Falls back to first N words when keyword extraction returns nothing useful.
struct NaturalLanguageSummarizer: Summarizer {
    private let maxFallbackWords = 5
    private let minNounLength = 2
    private let maxKeywordLabelChars = 20

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        summarizeSync(sentence, section: section)
    }

    private func isPrimarilyChinese(_ text: String) -> Bool {
        guard let lang = NLLanguageRecognizer.dominantLanguage(for: text) else { return false }
        return lang.rawValue.hasPrefix("zh")
    }

    private func summarizeSync(_ sentence: String, section: SummarizationSection) -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        var rawLabel: String
        var isTruncated: Bool

        if let label = extractKeywords(from: trimmed), !label.isEmpty {
            rawLabel = label
            isTruncated = label.count > maxKeywordLabelChars
            if isTruncated {
                rawLabel = firstTokensUpToMaxChars(label, maxChars: maxKeywordLabelChars)
            }
        } else {
            let fallback = firstNWords(from: trimmed)
            rawLabel = fallback.label
            isTruncated = fallback.isTruncated
        }

        let filtered = filterRedundantWords(from: rawLabel, section: section)
        return SummarizationResult(label: filtered, isTruncated: isTruncated)
    }

    private func filterRedundantWords(from label: String, section: SummarizationSection) -> String {
        let stopWords: Set<String>
        switch section {
        case .gratitude:
            stopWords = ["gratitude", "grateful", "thankful", "thank", "thanks", "感恩", "感谢", "感激"]
        case .need:
            stopWords = ["need", "needs", "want", "wants", "需要", "想要", "想"]
        case .person:
            stopWords = ["person", "people"]
        }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = label
        if isPrimarilyChinese(label) {
            tokenizer.setLanguage(NLLanguage(rawValue: "zh-Hans"))
        }
        var tokens: [String] = []
        let range = label.startIndex..<label.endIndex
        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            let word = String(label[tokenRange])
            let wordLower = word.lowercased()
            // Check both forms: lowercase for English, original for Chinese (no case folding)
            if !stopWords.contains(wordLower), !stopWords.contains(word) {
                tokens.append(word)
            }
            return true
        }

        let result = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? label : result
    }

    /// Extracts keywords for a short chip label: prefers named entities (people, places, orgs),
    /// then nouns, verbs, adjectives. Uses nameTypeOrLexicalClass with joinNames for multi-word names.
    private func extractKeywords(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = text
        if isPrimarilyChinese(text) {
            tagger.setLanguage(NLLanguage(rawValue: "zh-Hans"), range: text.startIndex..<text.endIndex)
        }

        var nameTokens: [String] = []
        var lexicalTokens: [String] = []
        let range = text.startIndex..<text.endIndex
        let options: NLTagger.Options = [.joinNames, .omitPunctuation, .omitWhitespace]

        tagger.enumerateTags(in: range, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, tokenRange in
            let word = String(text[tokenRange])
            guard word.count >= minNounLength else { return true }

            if let tag = tag {
                switch tag {
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
        if isPrimarilyChinese(text) {
            tokenizer.setLanguage(NLLanguage(rawValue: "zh-Hans"))
        }

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
        if isPrimarilyChinese(text) {
            tokenizer.setLanguage(NLLanguage(rawValue: "zh-Hans"))
        }
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
