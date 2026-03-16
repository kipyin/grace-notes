import XCTest
@testable import FiveCubedMoments

final class NaturalLanguageSummarizerTests: XCTestCase {
    private let sut = NaturalLanguageSummarizer()

    func test_summarize_emptyString_returnsEmptyLabel() {
        let result = sut.summarize("")
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_whitespaceOnly_returnsEmptyLabel() {
        let result = sut.summarize("   \n\t  ")
        XCTAssertEqual(result.label, "")
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_withNouns_extractsShortLabel() {
        let result = sut.summarize("I am grateful for my family")
        XCTAssertFalse(result.label.isEmpty)
        // NL may extract "grateful family" or "family" etc; label should be short
        XCTAssertLessThanOrEqual(result.label.count, 50)
        XCTAssertFalse(result.isTruncated)
    }

    func test_summarize_singleWord_returnsSensibleResult() {
        let result = sut.summarize("Family")
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertTrue(result.label.contains("Family") || result.label == "Family")
    }

    func test_summarize_longSentence_returnsNonEmptyLabel() {
        let result = sut.summarize("The quick brown fox jumps over the lazy dog")
        XCTAssertFalse(result.label.isEmpty)
    }

    func test_summarize_allArticles_returnsLabelWithoutCrash() {
        let result = sut.summarize("the the the")
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertTrue(result.isTruncated)
    }

    func test_summarize_shortNeedSentence_returnsNonEmptyLabel() {
        let result = sut.summarize("I need help")
        XCTAssertFalse(result.label.isEmpty)
    }
}
