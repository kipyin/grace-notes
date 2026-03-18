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

    func test_currentSummarizer_withoutFixedSummarizer_UserDefaultsKeyAbsent_returnsOnDeviceHybrid() {
        UserDefaults.standard.removeObject(forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is OnDeviceHybridSummarizer)
    }

    func test_currentSummarizer_withoutFixedSummarizer_UserDefaultsFalse_returnsOnDeviceHybrid() {
        UserDefaults.standard.set(false, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(result is OnDeviceHybridSummarizer)
    }

    func test_currentSummarizer_UserDefaultsTrue_placeholderKey_returnsOnDeviceHybrid() {
        UserDefaults.standard.set(true, forKey: SummarizerProvider.useCloudUserDefaultsKey)
        let provider = SummarizerProvider()

        let result = provider.currentSummarizer()

        XCTAssertTrue(
            result is OnDeviceHybridSummarizer,
            "With placeholder API key, provider should use on-device hybrid summarizer"
        )
    }
}
