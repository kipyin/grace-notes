import XCTest
@testable import GraceNotes

final class WeeklyInsightTextNormalizerTests: XCTestCase {
    private let normalizer = WeeklyInsightTextNormalizer()

    func test_normalizeThemeLabel_collapsesCaseAndPunctuation() {
        let normalized = normalizer.normalizeThemeLabel("  Morning, COFFEE!  ")

        XCTAssertEqual(normalized, "morning coffee")
    }

    func test_normalizeThemeLabel_preservesMixedLanguageTokens() {
        let normalized = normalizer.normalizeThemeLabel("  Rest 與 邊界  ")

        XCTAssertEqual(normalized, "rest 與 邊界")
    }

    func test_themesMatch_returnsTrue_whenExactMatchExists() {
        let result = normalizer.themesMatch("rest", against: ["rest", "family"])

        XCTAssertTrue(result)
    }

    func test_themesMatch_returnsTrue_whenOverlapTokenExists() {
        let result = normalizer.themesMatch(
            "better rest boundaries",
            against: ["rest boundaries gratitude"]
        )

        XCTAssertTrue(result)
    }

    func test_themesMatch_returnsFalse_whenThemesDoNotOverlap() {
        let result = normalizer.themesMatch("clarity", against: ["family", "friendship"])

        XCTAssertFalse(result)
    }

    func test_extractThemesFromText_emptyInput_returnsEmptyArray() {
        let themes = normalizer.extractThemesFromText("   ")

        XCTAssertTrue(themes.isEmpty)
    }
}
