import XCTest
@testable import GraceNotes

final class DeterministicChipLabelSummarizerTests: XCTestCase {
    private let sut = DeterministicChipLabelSummarizer()

    func test_summarize_emptyString_returnsEmptyLabel() async throws {
        let result = try await sut.summarize("", section: .gratitude)
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_englishSentence_returnsFirstFiveWords() async throws {
        let input = "I am grateful for my family and friends"
        let result = try await sut.summarize(input, section: .gratitude)

        XCTAssertEqual(result.label, "I am grateful for my")
        XCTAssertTrue(result.isTruncated)
    }

    func test_summarize_fiveOrFewerWordsWithinChipBudget_marksNotTruncated() async throws {
        let input = "Need wisdom today"
        let result = try await sut.summarize(input, section: .need)

        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_chineseSentence_returnsFirstFiveCharacters() async throws {
        let input = "今天我感恩有好朋友陪伴"
        let result = try await sut.summarize(input, section: .gratitude)

        XCTAssertEqual(result.label, "今天我感恩")
        XCTAssertTrue(result.isTruncated)
    }

    func test_summarize_chineseWithPunctuation_ignoresPunctuationInLabel() async throws {
        let input = "我，今天感恩。"
        let result = try await sut.summarize(input, section: .gratitude)

        XCTAssertEqual(result.label, "我今天感恩")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_personMixedLanguage_preservesLatinName() async throws {
        let input = "为 Amy 祷告平安"
        let result = try await sut.summarize(input, section: .person)

        XCTAssertEqual(result.label, input)
        XCTAssertTrue(result.label.contains("Amy"))
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_fiveOrFewerWords_overTwentyChars_capsToChipBudget() async throws {
        let input = "Extraordinary opportunities for collaboration"
        let result = try await sut.summarize(input, section: .need)

        XCTAssertEqual(result.label, String(input.prefix(20)))
        XCTAssertTrue(result.isTruncated)
    }
}
