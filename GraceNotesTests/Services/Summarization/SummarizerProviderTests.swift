import XCTest
@testable import GraceNotes

final class SummarizerProviderTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.legacyCloudSummarizationKey)
        super.tearDown()
    }

    func test_currentSummarizer_withFixedSummarizer_returnsFixedSummarizer() {
        let mock = MockSummarizer()
        let provider = SummarizerProvider(fixedSummarizer: mock)

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is MockSummarizer)
    }

    func test_currentSummarizer_withoutFixedSummarizer_aiFeaturesKeyAbsent_returnsDeterministicSummarizer() {
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.legacyCloudSummarizationKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is DeterministicChipLabelSummarizer)
    }

    func test_currentSummarizer_withoutFixedSummarizer_aiFeaturesDisabled_returnsDeterministicSummarizer() {
        UserDefaults.standard.set(false, forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is DeterministicChipLabelSummarizer)
    }

    func test_currentSummarizer_aiFeaturesEnabled_placeholderKey_returnsDeterministicSummarizer() {
        UserDefaults.standard.set(true, forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(
            result is DeterministicChipLabelSummarizer,
            "With placeholder API key, provider should use deterministic on-device summarizer"
        )
    }

    func test_currentSummarizer_legacyCloudKeyTrue_placeholderKey_returnsDeterministicSummarizer() {
        UserDefaults.standard.set(true, forKey: AIFeaturesSettings.legacyCloudSummarizationKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(
            result is DeterministicChipLabelSummarizer,
            "With placeholder API key, provider should use deterministic on-device summarizer"
        )
    }
}
