import XCTest
@testable import GraceNotes

final class ThemeDrilldownChipDisplayLabelTests: XCTestCase {
    private func label(display: String, canonical: String, line: String) -> String {
        let concept = ReviewDistilledConcept(
            canonicalConcept: canonical,
            displayLabel: display,
            score: 5
        )
        return ThemeDrilldownChipDisplayLabel.label(for: concept, lineText: line)
    }

    func test_shortLine_keepsFullLabel() {
        XCTAssertEqual(
            label(display: "王哥", canonical: "王哥", line: "王哥"),
            "王哥"
        )
    }

    func test_shortLineUpTo16Chars_keepsLabel() {
        let line = String(repeating: "字", count: 16)
        let longTag = String(repeating: "标", count: 30)
        XCTAssertEqual(
            label(display: longTag, canonical: "short", line: line),
            longTag
        )
    }

    func test_longLineLongLabel_prefersCanonicalWhenShorterThanDisplay() {
        let line = String(repeating: "a", count: 50)
        let longDisplay = String(repeating: "L", count: 45)
        let out = label(display: longDisplay, canonical: "short", line: line)
        XCTAssertEqual(out, "short")
    }

    func test_longLineLongLabel_prefersShorterCanonicalWhenHelpful() {
        let line = String(repeating: "x", count: 40)
        let longDisplay = String(repeating: "D", count: 40)
        let out = label(display: longDisplay, canonical: "name", line: line)
        XCTAssertEqual(out, "name")
    }
}
