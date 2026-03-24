import XCTest
@testable import GraceNotes

final class DeterministicChipLabelSummarizerTests: XCTestCase {
    private let sut = DeterministicChipLabelSummarizer()

    func test_summarize_emptyString_returnsEmptyLabel() async throws {
        let result = try await sut.summarize("", section: .gratitude)
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_nonEmpty_returnsFullTrimmedText() async throws {
        let input = "I am grateful for my family and friends"
        let result = try await sut.summarize(input, section: .gratitude)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_trimsWhitespace() async throws {
        let result = try await sut.summarize("  Peace  ", section: .need)
        XCTAssertEqual(result.label, "Peace")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_chinese_returnsFullTrimmedText() async throws {
        let input = "今天我感恩有好朋友陪伴"
        let result = try await sut.summarize(input, section: .gratitude)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_preservesPunctuation() async throws {
        let input = "我，今天感恩。"
        let result = try await sut.summarize(input, section: .gratitude)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_mixedLanguage_returnsFullTrimmedText() async throws {
        let input = "为 Amy 祷告平安"
        let result = try await sut.summarize(input, section: .person)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }
}

final class ChipLabelUnitTruncatorDisplayTests: XCTestCase {
    func test_displayCappedLabel_longEnglish_addsEllipsis() {
        let input = "I am grateful for my family and friends"
        let result = ChipLabelUnitTruncator.displayCappedLabel(from: input)
        XCTAssertEqual(result.label, "I am grate...")
        XCTAssertTrue(result.isTruncated)
    }

    func test_displayCappedLabel_shortText_noEllipsis() {
        let input = "Peace"
        let result = ChipLabelUnitTruncator.displayCappedLabel(from: input)
        XCTAssertEqual(result.label, "Peace")
        XCTAssertFalse(result.isTruncated)
    }

    func test_displayCappedLabel_chinese_addsEllipsisWhenNeeded() {
        let input = "今天我感恩有好朋友陪伴"
        let result = ChipLabelUnitTruncator.displayCappedLabel(from: input)
        XCTAssertEqual(result.label, "今天我感恩...")
        XCTAssertTrue(result.isTruncated)
    }

    func test_displayCappedLabel_mixedChineseAndLatin_addsEllipsisWhenNeeded() {
        let input = "为 Amy 祷告平安"
        let result = ChipLabelUnitTruncator.displayCappedLabel(from: input)
        XCTAssertEqual(result.label, "为 Amy 祷...")
        XCTAssertTrue(result.isTruncated)
    }

    func test_displayCappedLabel_fiveHanFitsExactly_noEllipsis() {
        let input = "为家人祷告"
        let result = ChipLabelUnitTruncator.displayCappedLabel(from: input)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }
}
