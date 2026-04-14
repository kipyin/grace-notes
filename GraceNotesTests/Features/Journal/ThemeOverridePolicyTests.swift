import XCTest
@testable import GraceNotes

final class ThemeOverridePolicyTests: XCTestCase {
    func test_apply_dropsHiddenCanonical() {
        let policy = ThemeOverridePolicy(
            hiddenCanonicalConcepts: ["rest"],
            canonicalRemap: [:],
            displayLabelOverrides: [:]
        )
        let concept = ReviewDistilledConcept(canonicalConcept: "rest", displayLabel: "Rest", score: 9)
        XCTAssertNil(policy.apply(concept))
    }

    func test_apply_remapsCanonicalBeforeDisplay() {
        let policy = ThemeOverridePolicy(
            hiddenCanonicalConcepts: [],
            canonicalRemap: ["rest": "calm"],
            displayLabelOverrides: [:]
        )
        let concept = ReviewDistilledConcept(canonicalConcept: "rest", displayLabel: "Rest", score: 9)
        XCTAssertEqual(policy.apply(concept)?.canonicalConcept, "calm")
    }

    func test_displayLabel_prefersOverride() {
        let policy = ThemeOverridePolicy(
            hiddenCanonicalConcepts: [],
            canonicalRemap: [:],
            displayLabelOverrides: ["sleep": "Better sleep"]
        )
        XCTAssertEqual(policy.displayLabel(for: "sleep", default: "Sleep"), "Better sleep")
        XCTAssertEqual(policy.displayLabel(for: "walk", default: "Walk"), "Walk")
    }
}
