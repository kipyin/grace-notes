import XCTest
@testable import GraceNotes

final class ICloudSyncLastActivityFormattingTests: XCTestCase {
    private let frozenNow = Date(timeIntervalSince1970: 1_700_000_000)
    private let englishUS = Locale(identifier: "en_US")

    func test_within24Hours_thirtySeconds_usesSecondsPhrase() {
        let last = frozenNow.addingTimeInterval(-30)
        let phrase = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: englishUS
        )
        XCTAssertEqual(phrase, "30 seconds ago")
    }

    func test_within24Hours_twentyFourMinutes_usesMinutesPhrase() {
        let last = frozenNow.addingTimeInterval(-24 * 60)
        let phrase = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: englishUS
        )
        XCTAssertEqual(phrase, "24 minutes ago")
    }

    func test_within24Hours_fiveHoursThirtyFiveMinutes_usesCompoundHoursMinutes() {
        let last = frozenNow.addingTimeInterval(-(5 * 3600 + 35 * 60))
        let phrase = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: englishUS
        )
        XCTAssertEqual(phrase, "5 hours and 35 minutes ago")
    }

    func test_exactlyTwentyFourHoursFromReference_usesAbsoluteAbbreviatedStyle() {
        let last = frozenNow.addingTimeInterval(-24 * 3600)
        let got = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: englishUS
        )
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(englishUS)
        let expected = last.formatted(style)
        XCTAssertEqual(got, expected)
    }

    func test_overTwentyFourHours_usesAbsoluteAbbreviatedStyle() {
        let last = frozenNow.addingTimeInterval(-25 * 3600)
        let got = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: englishUS
        )
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened).locale(englishUS)
        let expected = last.formatted(style)
        XCTAssertEqual(got, expected)
    }

    func test_oneHourExactly_usesHoursOnlyPhrase() {
        let last = frozenNow.addingTimeInterval(-3600)
        let phrase = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: englishUS
        )
        XCTAssertEqual(phrase, "1 hour ago")
    }

    func test_simplifiedChinese_within24Hours_matchesTranslatorStrings() {
        let simplifiedChinese = Locale(identifier: "zh_Hans_CN")
        let last = frozenNow.addingTimeInterval(-30)
        let phrase = ICloudSyncLastActivityFormatting.formattedActivityTime(
            lastActivity: last,
            referenceNow: frozenNow,
            localizationLocale: simplifiedChinese
        )
        XCTAssertEqual(phrase, "30 秒前")
    }
}
