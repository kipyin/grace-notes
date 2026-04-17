import XCTest
@testable import GraceNotes

/// Persistence tests for Today journal appearance (`JournalAppearanceMode`).
///
/// ``JournalAppearanceMode/resolveStored(rawValue:)`` lowercases stored keys with `en_US_POSIX` so
/// identifier matching stays stable across user locales. If normalization used `Locale.current` or
/// `String.lowercased()` alone, Turkish (and other) linguistic rules would diverge from POSIX for
/// Latin `I` (see ``testPOSIXLowercasingDiffersFromTurkishForLatinCapitalI``).
final class JournalAppearancePersistenceTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: JournalAppearanceStorageKeys.todayMode)
        super.tearDown()
    }

    func testTodayModeRoundTrip_standard() {
        let key = JournalAppearanceStorageKeys.todayMode
        UserDefaults.standard.set(JournalAppearanceMode.standard.rawValue, forKey: key)
        let raw = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: raw ?? ""), .standard)
    }

    func testTodayModeRoundTrip_bloom() {
        let key = JournalAppearanceStorageKeys.todayMode
        UserDefaults.standard.set(JournalAppearanceMode.bloom.rawValue, forKey: key)
        let raw = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: raw ?? ""), .bloom)
    }

    func test_resolveStored_mapsLegacySummerStringToBloom() {
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: "summer"), .bloom)
    }

    func test_resolveStored_normalizesWhitespaceAndCaseForBloom() {
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: " Bloom "), .bloom)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: "BLOOM"), .bloom)
    }

    func test_resolveStored_normalizesWhitespaceAndCaseForLegacySummer() {
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: "  summer  "), .bloom)
    }

    func test_resolveStored_normalizesWhitespaceAndCaseForStandard() {
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: " Standard "), .standard)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: "Standard"), .standard)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: "STANDARD"), .standard)
    }

    func testPOSIXLowercasingDiffersFromTurkishForLatinCapitalI() {
        let capitalILatin = "I"
        let posix = capitalILatin.lowercased(with: Locale(identifier: "en_US_POSIX"))
        let turkish = capitalILatin.lowercased(with: Locale(identifier: "tr_TR"))
        XCTAssertEqual(posix, "i")
        XCTAssertEqual(turkish, "ı")
        XCTAssertNotEqual(posix, turkish)
    }

    func test_migrateLegacyJournalAppearance_rewritesSummerRawToBloom() {
        let key = JournalAppearanceStorageKeys.todayMode
        UserDefaults.standard.set("summer", forKey: key)
        JournalAppearanceMode.migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: .standard)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), JournalAppearanceMode.bloom.rawValue)
        XCTAssertEqual(
            JournalAppearanceMode.resolveStored(rawValue: UserDefaults.standard.string(forKey: key) ?? ""),
            .bloom
        )
    }

    func test_migrateLegacyJournalAppearance_migratesWhitespacePaddedSummerInTestSuite() {
        let suiteName = "test.JournalAppearance.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test suite")
            return
        }
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let key = JournalAppearanceStorageKeys.todayMode
        defaults.set(" Summer ", forKey: key)
        JournalAppearanceMode.migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: key), JournalAppearanceMode.bloom.rawValue)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: defaults.string(forKey: key) ?? ""), .bloom)
    }

    func test_migrateLegacyJournalAppearance_migratesUppercasedSummerInTestSuite() {
        let suiteName = "test.JournalAppearance.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create test suite")
            return
        }
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let key = JournalAppearanceStorageKeys.todayMode
        defaults.set("SUMMER", forKey: key)
        JournalAppearanceMode.migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: key), JournalAppearanceMode.bloom.rawValue)
        XCTAssertEqual(JournalAppearanceMode.resolveStored(rawValue: defaults.string(forKey: key) ?? ""), .bloom)
    }
}
