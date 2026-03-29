import XCTest
@testable import GraceNotes

final class JournalAppearancePersistenceTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: JournalAppearanceStorageKeys.todayMode)
        UserDefaults.standard.removeObject(forKey: JournalAppearanceStorageKeys.summerLeavesRenderer)
        super.tearDown()
    }

    func testTodayModeRoundTrip_standard() {
        let key = JournalAppearanceStorageKeys.todayMode
        UserDefaults.standard.set(JournalAppearanceMode.standard.rawValue, forKey: key)
        let raw = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(JournalAppearanceMode(rawValue: raw ?? "") ?? .standard, .standard)
    }

    func testTodayModeRoundTrip_summer() {
        let key = JournalAppearanceStorageKeys.todayMode
        UserDefaults.standard.set(JournalAppearanceMode.summer.rawValue, forKey: key)
        let raw = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(JournalAppearanceMode(rawValue: raw ?? "") ?? .standard, .summer)
    }

    func testSummerLeavesRendererRoundTrip_video() {
        let key = JournalAppearanceStorageKeys.summerLeavesRenderer
        UserDefaults.standard.set(JournalSummerLeavesRenderer.video.rawValue, forKey: key)
        let raw = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(JournalSummerLeavesRenderer(rawValue: raw ?? ""), .video)
    }

    func testSummerLeavesRendererRoundTrip_native() {
        let key = JournalAppearanceStorageKeys.summerLeavesRenderer
        UserDefaults.standard.set(JournalSummerLeavesRenderer.native.rawValue, forKey: key)
        let raw = UserDefaults.standard.string(forKey: key)
        XCTAssertEqual(JournalSummerLeavesRenderer(rawValue: raw ?? ""), .native)
    }
}
