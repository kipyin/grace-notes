import XCTest
@testable import GraceNotes

final class ReminderSettingsTests: XCTestCase {
    func test_date_roundTripsFromStoredTimeInterval() {
        let originalDate = Date(timeIntervalSinceReferenceDate: 123_456)

        let recoveredDate = ReminderSettings.date(from: originalDate.timeIntervalSinceReferenceDate)

        XCTAssertEqual(recoveredDate.timeIntervalSinceReferenceDate, originalDate.timeIntervalSinceReferenceDate)
    }

    func test_timeComponents_extractsHourAndMinute() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 17
        components.hour = 19
        components.minute = 45
        components.timeZone = calendar.timeZone
        let date = calendar.date(from: components)!

        let extracted = ReminderSettings.timeComponents(from: date, calendar: calendar)

        XCTAssertEqual(extracted.hour, 19)
        XCTAssertEqual(extracted.minute, 45)
    }

    func test_sanitizedTimeInterval_nonFinite_fallsBackToDefault() {
        XCTAssertEqual(
            ReminderSettings.sanitizedTimeInterval(stored: .nan),
            ReminderSettings.defaultTimeInterval
        )
        XCTAssertEqual(
            ReminderSettings.sanitizedTimeInterval(stored: .infinity),
            ReminderSettings.defaultTimeInterval
        )
        XCTAssertEqual(
            ReminderSettings.sanitizedTimeInterval(stored: -.infinity),
            ReminderSettings.defaultTimeInterval
        )
    }

    func test_coercedTimeIntervalFromUserDefaults_repairsNonFiniteStorage() {
        let suiteName = "ReminderSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        defaults.set(Double.nan, forKey: ReminderSettings.timeIntervalKey)
        let coerced = ReminderSettings.coercedTimeInterval(fromUserDefaults: defaults)
        XCTAssertEqual(coerced, ReminderSettings.defaultTimeInterval)
        XCTAssertEqual(
            defaults.object(forKey: ReminderSettings.timeIntervalKey) as? TimeInterval,
            ReminderSettings.defaultTimeInterval
        )
    }
}
