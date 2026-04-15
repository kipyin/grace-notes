import XCTest
@testable import GraceNotes

final class ReviewJournalThemeLanguageResolverTests: XCTestCase {
    func test_resolvedDisplayLocale_shortCorpus_fallsBackToEnglish() {
        let resolver = ReviewJournalThemeLanguageResolver(
            minimumMeaningfulGraphemes: 200,
            confidenceThreshold: 0.55
        )
        let locale = resolver.resolvedDisplayLocale(forJournalCorpus: String(repeating: "休", count: 10))
        XCTAssertEqual(locale.identifier, "en")
    }

    func test_resolvedDisplayLocale_highThreshold_fallsBackToScriptTieBreak() {
        let resolver = ReviewJournalThemeLanguageResolver(
            minimumMeaningfulGraphemes: 8,
            confidenceThreshold: 1.0
        )
        let corpus = String(repeating: "休息", count: 20)
        let locale = resolver.resolvedDisplayLocale(forJournalCorpus: corpus)
        XCTAssertEqual(locale.identifier, "zh-Hans")
    }

    func test_resolvedDisplayLocale_latinWinsTieBreakWhenNoStrongHypothesis() {
        let resolver = ReviewJournalThemeLanguageResolver(
            minimumMeaningfulGraphemes: 8,
            confidenceThreshold: 1.0
        )
        let corpus = String(repeating: "abcde ", count: 30)
        let locale = resolver.resolvedDisplayLocale(forJournalCorpus: corpus)
        XCTAssertEqual(locale.identifier, "en")
    }

    func test_resolvedDisplayLocale_sparseAnalysisPrefixDenseTail_fallsBackToEnglish() {
        let resolver = ReviewJournalThemeLanguageResolver()
        // One meaningful grapheme in the first 50k clusters, then spaces to fill the prefix, then dense
        // Chinese: the meaningful-grapheme gate only sees the analysis prefix, so we fall back to English.
        let sparseHead = "A" + String(repeating: " ", count: 49_999)
        let denseTail = String(repeating: "休", count: 10_000)
        let locale = resolver.resolvedDisplayLocale(forJournalCorpus: sparseHead + denseTail)
        XCTAssertEqual(locale.identifier, "en")
    }
}
