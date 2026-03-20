import XCTest
@testable import GraceNotes

final class SummarizerProviderTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: SummarizerProvider.useCloudUserDefaultsKey)
        super.tearDown()
    }

    func test_currentSummarizer_withFixedSummarizer_returnsFixedSummarizer() {
        let mock = MockSummarizer()
        let provider = SummarizerProvider(fixedSummarizer: mock)

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is MockSummarizer)
    }

    func test_currentSummarizer_withoutFixedSummarizer_UserDefaultsKeyAbsent_returnsDeterministicSummarizer() {
        UserDefaults.standard.removeObject(forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is DeterministicChipLabelSummarizer)
    }

    func test_currentSummarizer_withoutFixedSummarizer_UserDefaultsFalse_returnsDeterministicSummarizer() {
        UserDefaults.standard.set(false, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is DeterministicChipLabelSummarizer)
    }

    func test_currentSummarizer_UserDefaultsTrue_placeholderKey_returnsDeterministicSummarizer() {
        UserDefaults.standard.set(true, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(
            result is DeterministicChipLabelSummarizer,
            "With placeholder API key, provider should use deterministic on-device summarizer"
        )
    }

    func test_effectiveUsesCloudForChips_withFixedSummarizer_returnsFalse() {
        UserDefaults.standard.set(true, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider(fixedSummarizer: MockSummarizer())

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_useCloudFalse_returnsFalse() {
        UserDefaults.standard.set(false, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_useCloudTrue_placeholderKey_returnsFalse() {
        UserDefaults.standard.set(true, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }
}
