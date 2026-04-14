import Foundation
import NaturalLanguage

/// Chooses the locale used for **curated** Past tab theme chip copy from journal text (issue #245).
/// Offline and deterministic given the same corpus and thresholds.
protocol ReviewJournalThemeLanguageResolving: Sendable {
    func resolvedDisplayLocale(forJournalCorpus corpus: String) -> Locale
}

struct ReviewJournalThemeLanguageResolver: ReviewJournalThemeLanguageResolving {
    /// Ignore language detection until the corpus has at least this many non-whitespace graphemes.
    private let minimumMeaningfulGraphemes: Int
    /// If the top `NLLanguageRecognizer` hypothesis is weaker than this, fall back to script share.
    private let confidenceThreshold: Double

    init(minimumMeaningfulGraphemes: Int = 24, confidenceThreshold: Double = 0.55) {
        self.minimumMeaningfulGraphemes = max(0, minimumMeaningfulGraphemes)
        if confidenceThreshold.isNaN {
            self.confidenceThreshold = 0.55
        } else {
            self.confidenceThreshold = min(max(confidenceThreshold, 0), 1)
        }
    }

    func resolvedDisplayLocale(forJournalCorpus corpus: String) -> Locale {
        let trimmed = corpus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Self.englishCatalogLocale
        }

        guard Self.hasEnoughMeaningfulGraphemes(trimmed, minimum: minimumMeaningfulGraphemes) else {
            return Self.englishCatalogLocale
        }

        let analysisText = Self.normalizedAnalysisSample(from: trimmed)

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(analysisText)

        if let dominant = recognizer.dominantLanguage {
            let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
            let confidence = hypotheses[dominant] ?? 0
            if confidence.isFinite && confidence >= confidenceThreshold {
                return Self.catalogLocale(for: dominant)
            }
        }

        return Self.scriptTieBreakLocale(analysisText: analysisText)
    }

    private static let englishCatalogLocale = Locale(identifier: "en")

    /// Upper bound on text fed to `NLLanguageRecognizer` and script tie-break (prefix by extended grapheme cluster).
    private static let maximumAnalysisGraphemes = 50_000

    /// Counts non-whitespace graphemes only in the same prefix we analyze, so the threshold matches
    /// `normalizedAnalysisSample` and pathological corpora cannot spend unbounded time here.
    private static func hasEnoughMeaningfulGraphemes(_ text: String, minimum: Int) -> Bool {
        if minimum <= 0 {
            return true
        }

        let prefix = text.prefix(maximumAnalysisGraphemes)
        var count = 0
        for character in prefix where !character.isWhitespace {
            count += 1
            if count >= minimum {
                return true
            }
        }
        return false
    }

    /// Collapses whitespace runs only inside the analysis prefix so pathological corpora never run a full-string
    /// regex replace.
    private static func normalizedAnalysisSample(from trimmed: String) -> String {
        let head = String(trimmed.prefix(maximumAnalysisGraphemes))
        return collapseWhitespaceRuns(head)
    }

    private static func collapseWhitespaceRuns(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Maps recognizer output to a locale that exists in `Localizable.xcstrings` (we ship `en` + `zh-Hans`).
    private static func catalogLocale(for language: NLLanguage) -> Locale {
        if language.rawValue.hasPrefix("zh") {
            return Locale(identifier: "zh-Hans")
        }
        return Locale(identifier: "en")
    }

    /// When hypotheses are ambiguous, count Han vs Latin letters and pick a side. Equal counts → English.
    /// Latin includes common accented letters (Latin-1 + Extended-A) so tie-break matches mixed European text.
    private static func scriptTieBreakLocale(analysisText: String) -> Locale {
        var han = 0
        var latin = 0
        for scalar in analysisText.unicodeScalars {
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
                han += 1
            case 0x41...0x5A, 0x61...0x7A,
                 0x00C0...0x00D6, 0x00D8...0x00F6, 0x00F8...0x00FF,
                 0x0100...0x017F:
                latin += 1
            default:
                break
            }
        }
        if han > latin {
            return Locale(identifier: "zh-Hans")
        }
        return englishCatalogLocale
    }
}
