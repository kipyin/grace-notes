import XCTest
@testable import GraceNotes

final class OnDeviceHybridSummarizerTests: XCTestCase {
    private let sut = DeterministicChipLabelSummarizer()

    func test_summarize_longEnglish_returnsFullTrimmedText() async throws {
        let input = "I need clearer priorities and fewer context switches"
        let result = try await sut.summarize(input, section: .need)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_chinese_returnsFullTrimmedText() async throws {
        let input = "今天我感恩有好朋友陪伴"
        let result = try await sut.summarize(input, section: .gratitude)
        XCTAssertEqual(result.label, input)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_emptyInput_returnsEmptyLabel() async throws {
        let result = try await sut.summarize("   ", section: .gratitude)
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_mixedLanguage_returnsFullText() async throws {
        let input = "为 Amy 祷告平安"
        let result = try await sut.summarize(input, section: .person)
        XCTAssertEqual(result.label, input)
        XCTAssertTrue(result.label.contains("Amy"))
        XCTAssertFalse(result.isTruncated)
    }

    func test_displayCappedLabel_longNeedSentence_addsEllipsis() {
        let input = "Need to reserve one focused block for AI project planning today"
        let result = ChipLabelUnitTruncator.displayCappedLabel(from: input)
        XCTAssertEqual(result.label, "Need to re...")
        XCTAssertTrue(result.isTruncated)
    }
}
