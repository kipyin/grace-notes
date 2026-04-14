import XCTest
@testable import GraceNotes

final class ThemeSubstitutionMergeTriggerTests: XCTestCase {
    func test_derive_prefersTargetSubstringInLine() {
        let derived = ThemeSubstitutionMergeTrigger.derive(
            line: "I love family time",
            fromCanonical: "work",
            toCanonical: "family"
        )
        XCTAssertEqual(derived, "family")
    }

    func test_derive_fallsBackToSourceWhenTargetNotInLine() {
        let derived = ThemeSubstitutionMergeTrigger.derive(
            line: "希望我哥哥身体健康",
            fromCanonical: "哥哥",
            toCanonical: "王哥"
        )
        XCTAssertEqual(derived, "哥哥")
    }

    func test_derive_usesShortLineWhenNeitherMatches() {
        let line = "短句"
        let derived = ThemeSubstitutionMergeTrigger.derive(
            line: line,
            fromCanonical: "a",
            toCanonical: "b"
        )
        XCTAssertEqual(derived, line)
    }

    func test_derive_prefixesLongLineWhenNeitherMatches() {
        let line = String(repeating: "字", count: 40)
        let derived = ThemeSubstitutionMergeTrigger.derive(
            line: line,
            fromCanonical: "x",
            toCanonical: "y"
        )
        XCTAssertEqual(derived?.count, 24)
    }
}
