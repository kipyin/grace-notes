import Foundation

/// Deterministic chip labels without NLP: first 5 words, or first 5 Chinese characters.
struct DeterministicChipLabelSummarizer: Summarizer {
    private let maxWordCount = 5
    private let maxChineseCharacterCount = 5

    func summarize(_ sentence: String, section: SummarizationSection) async throws -> SummarizationResult {
        summarizeSync(sentence, section: section)
    }

    func summarizeSync(_ sentence: String, section: SummarizationSection) -> SummarizationResult {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SummarizationResult(label: "", isTruncated: false)
        }

        // Keep person names visible in mixed-language entries like "为 Amy 祷告平安".
        if section == .person, containsLatinLetters(trimmed) {
            return summarizeNonChineseText(trimmed)
        }

        if isPrimarilyChinese(trimmed) {
            return summarizeChineseText(trimmed)
        }

        return summarizeNonChineseText(trimmed)
    }

    private func summarizeChineseText(_ text: String) -> SummarizationResult {
        var labelCharacters: [Character] = []
        var chineseCharacterCount = 0

        for character in text where character.containsHanScalar {
            chineseCharacterCount += 1
            if labelCharacters.count < maxChineseCharacterCount {
                labelCharacters.append(character)
            }
        }

        if !labelCharacters.isEmpty {
            return capLabel(
                String(labelCharacters),
                alreadyTruncated: chineseCharacterCount > maxChineseCharacterCount
            )
        }

        return summarizeNonChineseText(text)
    }

    private func summarizeNonChineseText(_ text: String) -> SummarizationResult {
        let words = text
            .split(whereSeparator: {
                $0.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
            })
            .map(String.init)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        guard !words.isEmpty else {
            return SummarizationResult(label: "", isTruncated: false)
        }

        let label = words.prefix(maxWordCount).joined(separator: " ")
        return capLabel(label, alreadyTruncated: words.count > maxWordCount)
    }

    private func capLabel(_ label: String, alreadyTruncated: Bool) -> SummarizationResult {
        let capped = ChipLabelUnitTruncator.truncate(label)
        return SummarizationResult(
            label: capped.label,
            isTruncated: alreadyTruncated || capped.isTruncated
        )
    }

    private func isPrimarilyChinese(_ text: String) -> Bool {
        var hanScalarCount = 0
        var nonHanLetterCount = 0

        for scalar in text.unicodeScalars {
            if Self.isHanScalar(scalar) {
                hanScalarCount += 1
            } else if CharacterSet.letters.contains(scalar) {
                nonHanLetterCount += 1
            }
        }

        guard hanScalarCount > 0 else { return false }
        return hanScalarCount >= nonHanLetterCount
    }

    private func containsLatinLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(scalar.value)
                || (0x0061...0x007A).contains(scalar.value)
                || (0x00C0...0x024F).contains(scalar.value)
        }
    }

    fileprivate static func isHanScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, // CJK Unified Ideographs Extension A
             0x4E00...0x9FFF, // CJK Unified Ideographs
             0xF900...0xFAFF, // CJK Compatibility Ideographs
             0x20000...0x2A6DF, // CJK Unified Ideographs Extension B
             0x2A700...0x2B73F, // CJK Unified Ideographs Extension C
             0x2B740...0x2B81F, // CJK Unified Ideographs Extension D
             0x2B820...0x2CEAF, // CJK Unified Ideographs Extension E
             0x2CEB0...0x2EBEF, // CJK Unified Ideographs Extension F
             0x2F800...0x2FA1F: // CJK Compatibility Ideographs Supplement
            return true
        default:
            return false
        }
    }
}

private extension Character {
    var containsHanScalar: Bool {
        unicodeScalars.contains { DeterministicChipLabelSummarizer.isHanScalar($0) }
    }
}
