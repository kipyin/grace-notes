import XCTest
@testable import GraceNotes

final class SummarizerProviderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Hosted tests use the app Info.plist; local developer keys must not change these expectations.
        ApiSecrets.cloudApiKeyOverrideForTesting = "YOUR_KEY_HERE"
    }

    override func tearDown() {
        ApiSecrets.cloudApiKeyOverrideForTesting = nil
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
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.legacyCloudSummarizationKey)
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

    func test_effectiveUsesCloudForChips_withFixedSummarizer_returnsFalse() {
        UserDefaults.standard.set(true, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider(fixedSummarizer: MockSummarizer())

        XCTAssertFalse(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_fixedSummarizer_overrideTrue_returnsTrue() {
        UserDefaults.standard.set(false, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider(
            fixedSummarizer: MockSummarizer(),
            effectiveUsesCloudForChipsOverride: true
        )

        XCTAssertTrue(provider.effectiveUsesCloudForChips())
    }

    func test_effectiveUsesCloudForChips_fixedSummarizer_overrideFalse_returnsFalse() {
        UserDefaults.standard.set(true, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider(
            fixedSummarizer: MockSummarizer(),
            effectiveUsesCloudForChipsOverride: false
        )

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
