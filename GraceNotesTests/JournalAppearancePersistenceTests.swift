import XCTest
@testable import GraceNotes

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

    func test_migrateLegacySummer_rewritesStoredRawToBloom() {
        let key = JournalAppearanceStorageKeys.todayMode
        UserDefaults.standard.set("summer", forKey: key)
        JournalAppearanceMode.migrateLegacySummerRawValueIfNeeded(defaults: .standard)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), JournalAppearanceMode.bloom.rawValue)
        XCTAssertEqual(
            JournalAppearanceMode.resolveStored(rawValue: UserDefaults.standard.string(forKey: key) ?? ""),
            .bloom
        )
    }
}
