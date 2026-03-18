import Foundation
import NaturalLanguage

struct WeeklyInsightTextNormalizer {
    func extractThemesFromText(_ text: String) -> [String] {
        let source = trimmed(text)
        guard !source.isEmpty else { return [] }

        let textRange = source.startIndex..<source.endIndex
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = source
        if let language = NLLanguageRecognizer.dominantLanguage(for: source) {
            tagger.setLanguage(language, range: textRange)
        }

        var extracted: [String: Int] = [:]
        var displayLabels: [String: String] = [:]
        var sequence = 0
        var firstSeenOrder: [String: Int] = [:]

        let options: NLTagger.Options = [.joinNames, .omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(
            in: textRange,
            unit: .word,
            scheme: .nameTypeOrLexicalClass,
            options: options
        ) { tag, tokenRange in
            let token = String(source[tokenRange])
            guard shouldIncludeTextToken(token, tag: tag) else { return true }
            let normalized = normalizeThemeLabel(token)
            guard !normalized.isEmpty else { return true }
            guard !isStopWord(normalized) else { return true }

            extracted[normalized, default: 0] += 1
            if displayLabels[normalized] == nil {
                displayLabels[normalized] = trimmed(token)
            }
            if firstSeenOrder[normalized] == nil {
                firstSeenOrder[normalized] = sequence
            }
            sequence += 1
            return true
        }

        return extracted
            .sorted {
                if $0.value != $1.value {
                    return $0.value > $1.value
                }
                let lhsOrder = firstSeenOrder[$0.key] ?? .max
                let rhsOrder = firstSeenOrder[$1.key] ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return $0.key < $1.key
            }
            .prefix(3)
            .compactMap { displayLabels[$0.key] }
    }

    func themesMatch(_ needKey: String, against gratitudeKeys: Set<String>) -> Bool {
        if gratitudeKeys.contains(needKey) {
            return true
        }

        for gratitudeKey in gratitudeKeys where overlapScore(between: needKey, and: gratitudeKey) >= 1 {
            return true
        }
        return false
    }

    func normalizeThemeLabel(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let withoutSymbols = folded.replacingOccurrences(
            of: "[\\p{P}\\p{S}]+",
            with: " ",
            options: .regularExpression
        )
        let collapsedSpaces = withoutSymbols.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return trimmed(collapsedSpaces)
    }

    func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldIncludeTextToken(_ token: String, tag: NLTag?) -> Bool {
        let clean = trimmed(token)
        guard !clean.isEmpty else { return false }

        let hasHan = containsHanCharacters(clean)
        let minimumLength = hasHan ? 1 : 3
        guard clean.count >= minimumLength else { return false }

        guard let tag else { return false }
        switch tag {
        case .personalName, .placeName, .organizationName, .noun:
            return true
        default:
            return false
        }
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

    private func isStopWord(_ normalizedToken: String) -> Bool {
        let englishStopWords: Set<String> = [
            "with", "from", "that", "this", "your", "have", "will", "about", "into",
            "today", "week", "really", "just", "very", "more", "need", "needs", "gratitude",
            "grateful", "thankful"
        ]
        let chineseStopWords: Set<String> = [
            "今天", "这个", "那个", "我们", "你们", "他们", "自己", "需要", "感恩", "感谢"
        ]
        return englishStopWords.contains(normalizedToken) || chineseStopWords.contains(normalizedToken)
    }

    private func overlapScore(between lhs: String, and rhs: String) -> Int {
        let lhsTokens = Set(lhs.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        if lhsTokens.isEmpty || rhsTokens.isEmpty {
            return 0
        }
        return lhsTokens.intersection(rhsTokens).count
    }
}
