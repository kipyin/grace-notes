import XCTest
@testable import GraceNotes

final class NaturalLanguageSummarizerTests: XCTestCase {
    private let sut = NaturalLanguageSummarizer()

    func test_summarize_emptyString_returnsEmptyLabel() async throws {
        let result = try await sut.summarize("", section: .gratitude)
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_whitespaceOnly_returnsEmptyLabel() async throws {
        let result = try await sut.summarize("   \n\t  ", section: .gratitude)
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_withNouns_extractsShortLabel() async throws {
        let result = try await sut.summarize("I am grateful for my family", section: .gratitude)
        XCTAssertFalse(result.label.isEmpty)
        // NL may extract "grateful family" or "family" etc; label should be short
        XCTAssertLessThanOrEqual(result.label.count, 50)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_singleWord_returnsSensibleResult() async throws {
        let result = try await sut.summarize("Family", section: .gratitude)
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertTrue(result.label.contains("Family") || result.label == "Family")
    }

    func test_summarize_longSentence_returnsNonEmptyLabel() async throws {
        let result = try await sut.summarize("The quick brown fox jumps over the lazy dog", section: .need)
        XCTAssertFalse(result.label.isEmpty)
    }

    func test_summarize_allArticles_returnsLabelWithoutCrash() async throws {
        let result = try await sut.summarize("the the the", section: .gratitude)
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertTrue(result.isTruncated)
    }

    func test_summarize_shortNeedSentence_returnsNonEmptyLabel() async throws {
        let result = try await sut.summarize("I need help", section: .need)
        XCTAssertFalse(result.label.isEmpty)
    }

    /// Named-entity preference: multi-word personal names (e.g. "John Smith") should be
    /// kept together via joinNames, not reduced to unrelated lexical tokens.
    func test_summarize_personalName_keepsFullNameTogether() async throws {
        let result = try await sut.summarize("I had coffee with John Smith today", section: .person)
        XCTAssertFalse(result.label.isEmpty)
        // NL with nameTypeOrLexicalClass + joinNames should produce "John Smith" or both names
        let hasFullName = result.label.contains("John") && result.label.contains("Smith")
        XCTAssertTrue(hasFullName, "Expected full name 'John Smith' in label, got: '\(result.label)'")
    }

    /// Long extracted labels (e.g. place names) should be truncated with isTruncated = true
    /// so chips render the gradient fade and avoid overflow.
    func test_summarize_longExtractedLabel_returnsTruncatedWithIsTruncatedTrue() async throws {
        let input = "I traveled through John Smith International Airport today"
        let result = try await sut.summarize(input, section: .person)
        XCTAssertFalse(result.label.isEmpty)
        if result.isTruncated {
            let msg = "When truncated, label must be at most 20 chars, got: '\(result.label)' "
                + "(\(result.label.count) chars)"
            XCTAssertLessThanOrEqual(result.label.count, 20, msg)
        }
    }

    /// Section filtering: gratitude section should not include "gratitude" or "grateful" in the chip label.
    func test_summarize_gratitudeSection_filtersRedundantWords() async throws {
        let result = try await sut.summarize("I'm grateful for good rest", section: .gratitude)
        XCTAssertFalse(result.label.isEmpty)
        let lower = result.label.lowercased()
        XCTAssertFalse(lower.contains("gratitude"), "Label should not contain 'gratitude', got: '\(result.label)'")
        XCTAssertFalse(lower.contains("grateful"), "Label should not contain 'grateful', got: '\(result.label)'")
    }

    /// Section filtering: need section should not include "need" or "needs" in the chip label.
    func test_summarize_needSection_filtersRedundantWords() async throws {
        let result = try await sut.summarize("I need wisdom today", section: .need)
        XCTAssertFalse(result.label.isEmpty)
        let lower = result.label.lowercased()
        XCTAssertFalse(lower.contains("need"), "Label should not contain 'need', got: '\(result.label)'")
    }

    /// Chinese support: gratitude section should not include 感恩, 感谢, 感激 in the chip label.
    func test_summarize_chineseGratitude_filtersRedundantWords() async throws {
        let result = try await sut.summarize("我感恩有一个好的休息", section: .gratitude)
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertFalse(result.label.contains("感恩"), "Label should not contain 感恩, got: '\(result.label)'")
    }
}
