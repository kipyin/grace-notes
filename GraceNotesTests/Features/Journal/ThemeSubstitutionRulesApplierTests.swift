import XCTest
@testable import GraceNotes

final class ThemeSubstitutionRulesApplierTests: XCTestCase {
    private var normalizer: WeeklyInsightTextNormalizer!

    override func setUp() {
        super.setUp()
        normalizer = WeeklyInsightTextNormalizer()
    }

    func test_apply_remapsWhenTriggerAndFromMatch() {
        let concept = ReviewDistilledConcept(
            canonicalConcept: "哥哥",
            displayLabel: "哥哥",
            score: 5
        )
        let rules = [
            ThemeSubstitutionRule(
                surfaceTextMustContain: "王哥",
                fromCanonical: "哥哥",
                toCanonical: "王哥"
            )
        ]
        let out = ThemeSubstitutionRulesApplier.apply(
            to: concept,
            surfaceText: "王哥希望我哥哥身体健康",
            rules: rules,
            textNormalizer: normalizer,
            source: .gratitudes,
            journalThemeDisplayLocale: Locale(identifier: "zh-Hans")
        )
        XCTAssertEqual(out.canonicalConcept, "王哥")
        XCTAssertEqual(out.score, 5)
    }

    func test_apply_noRemapWithoutTriggerEvenWhenFromMatches() {
        let concept = ReviewDistilledConcept(
            canonicalConcept: "哥哥",
            displayLabel: "哥哥",
            score: 5
        )
        let rules = [
            ThemeSubstitutionRule(
                surfaceTextMustContain: "王哥",
                fromCanonical: "哥哥",
                toCanonical: "王哥"
            )
        ]
        let out = ThemeSubstitutionRulesApplier.apply(
            to: concept,
            surfaceText: "希望我哥哥身体健康",
            rules: rules,
            textNormalizer: normalizer,
            source: .gratitudes,
            journalThemeDisplayLocale: Locale(identifier: "zh-Hans")
        )
        XCTAssertEqual(out.canonicalConcept, "哥哥")
    }

    func test_apply_firstRuleWins() {
        let concept = ReviewDistilledConcept(
            canonicalConcept: "foo",
            displayLabel: "foo",
            score: 3
        )
        let rules = [
            ThemeSubstitutionRule(surfaceTextMustContain: "x", fromCanonical: "foo", toCanonical: "bar"),
            ThemeSubstitutionRule(surfaceTextMustContain: "x", fromCanonical: "foo", toCanonical: "baz")
        ]
        let out = ThemeSubstitutionRulesApplier.apply(
            to: concept,
            surfaceText: "x foo",
            rules: rules,
            textNormalizer: normalizer,
            source: .needs,
            journalThemeDisplayLocale: Locale(identifier: "en")
        )
        XCTAssertEqual(out.canonicalConcept, "bar")
    }
}
