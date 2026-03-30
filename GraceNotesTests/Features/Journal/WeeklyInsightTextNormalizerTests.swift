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

    func test_distillConcepts_appliesSectionOverridesAndAliases() throws {
        let concepts = normalizer.distillConcepts(
            from: "I need more time alone and quiet morning rhythm.",
            source: .needs
        )

        let labels = Set(concepts.map(\.displayLabel))
        XCTAssertTrue(labels.contains("Personal time"))
        XCTAssertTrue(labels.contains("Quiet time"))
    }

    func test_distillConcepts_mergesHighConfidenceCrossLanguageVariants() throws {
        let concepts = normalizer.distillConcepts(
            from: "休息與睡眠都需要調整",
            source: .needs
        )

        let labels = Set(concepts.map(\.displayLabel))
        XCTAssertTrue(labels.contains("Rest"))
        XCTAssertTrue(labels.contains("Sleep"))
    }

    func test_distillConcepts_limitsToThreeHighConfidenceConcepts() {
        let concepts = normalizer.distillConcepts(
            from: "morning walk with prayer, focused work blocks, and family dinner",
            source: .gratitudes
        )

        XCTAssertLessThanOrEqual(concepts.count, 3)
    }

    func test_distillConcepts_singleWordWalkingChip_mapsToWalkingTheme() {
        let concepts = normalizer.distillConcepts(from: "walking", source: .gratitudes)
        let labels = Set(concepts.map(\.displayLabel))
        XCTAssertTrue(labels.contains("Walking"))
    }

    func test_distillConcepts_peopleStayLiteral() throws {
        let concepts = normalizer.distillConcepts(from: "  MIA  ", source: .people)
        let first = try XCTUnwrap(concepts.first)
        XCTAssertEqual(first.canonicalConcept, "mia")
        XCTAssertEqual(first.displayLabel, "Mia")
    }

    func test_distillConcepts_omitsHardBannedSurface() {
        let concepts = normalizer.distillConcepts(from: "reflection", source: .needs)

        XCTAssertTrue(concepts.isEmpty)
    }

    func test_distillConcepts_omitsGenericSectionAndPrayerLabels() {
        XCTAssertTrue(normalizer.distillConcepts(from: "Gratitude", source: .gratitudes).isEmpty)
        XCTAssertTrue(normalizer.distillConcepts(from: "need", source: .needs).isEmpty)
        XCTAssertTrue(normalizer.distillConcepts(from: "Prayer", source: .gratitudes).isEmpty)
        XCTAssertTrue(normalizer.distillConcepts(from: "pray", source: .needs).isEmpty)
    }

    func test_distillConcepts_workPressureKeepsStrongContext() throws {
        let concepts = normalizer.distillConcepts(from: "Heavy work stress this week", source: .needs)
        let labels = Set(concepts.map(\.displayLabel))
        XCTAssertTrue(labels.contains("Work pressure"))
    }

    func test_themesMatch_findsOverlapOnCanonicalStrings() {
        XCTAssertTrue(normalizer.themesMatch("rest", against: Set(["rest",
                                                                   "quiet time"])))
        XCTAssertTrue(
            normalizer.themesMatch("rest boundaries", against: Set(["sleep", "rest healing"]))
        )
    }
}
