import XCTest
@testable import GraceNotes

final class SummarizerProviderTests: XCTestCase {
    func test_currentSummarizer_withFixedSummarizer_returnsFixedSummarizer() {
        let mock = MockSummarizer()
        let provider = SummarizerProvider(fixedSummarizer: mock)

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is MockSummarizer)
    }

    func test_currentSummarizer_withoutFixedSummarizer_returnsDeterministicSummarizer() {
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is DeterministicChipLabelSummarizer)
    }

    func test_effectiveUsesCloudForChips_withFixedSummarizer_returnsFalse() {
        let provider = SummarizerProvider(fixedSummarizer: MockSummarizer())

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_fixedSummarizer_overrideTrue_returnsTrue() {
        let provider = SummarizerProvider(
            fixedSummarizer: MockSummarizer(),
            effectiveUsesCloudForChipsOverride: true
        )

        XCTAssertTrue(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_fixedSummarizer_overrideFalse_returnsFalse() {
        let provider = SummarizerProvider(
            fixedSummarizer: MockSummarizer(),
            effectiveUsesCloudForChipsOverride: false
        )

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_withoutOverride_returnsFalse() {
        let provider = SummarizerProvider()

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }
}
