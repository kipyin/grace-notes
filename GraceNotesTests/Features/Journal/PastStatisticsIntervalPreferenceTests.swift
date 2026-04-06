import XCTest
@testable import GraceNotes

final class PastStatisticsIntervalPreferenceTests: XCTestCase {
    func test_statisticsIntervalSubtitlePhrase_customQuantityOne_usesSingularStrings() {
        XCTAssertEqual(
            subtitlePhrase(quantity: 1, unit: .week),
            String(localized: "settings.pastStatisticsInterval.phrase.lastOneWeek")
        )
        XCTAssertEqual(
            subtitlePhrase(quantity: 1, unit: .month),
            String(localized: "settings.pastStatisticsInterval.phrase.lastOneMonth")
        )
        XCTAssertEqual(
            subtitlePhrase(quantity: 1, unit: .year),
            String(localized: "settings.pastStatisticsInterval.phrase.lastOneYear")
        )
    }

    func test_statisticsIntervalSubtitlePhrase_customQuantityTwo_usesPluralFormatStrings() {
        XCTAssertEqual(
            subtitlePhrase(quantity: 2, unit: .week),
            String(format: String(localized: "settings.pastStatisticsInterval.phrase.lastNWeeks"), Int64(2))
        )
        XCTAssertEqual(
            subtitlePhrase(quantity: 2, unit: .month),
            String(format: String(localized: "settings.pastStatisticsInterval.phrase.lastNMonths"), Int64(2))
        )
        XCTAssertEqual(
            subtitlePhrase(quantity: 2, unit: .year),
            String(format: String(localized: "settings.pastStatisticsInterval.phrase.lastNYears"), Int64(2))
        )
    }

    private func subtitlePhrase(quantity: Int, unit: PastStatisticsIntervalUnit) -> String {
        PastStatisticsIntervalSelection(mode: .custom, quantity: quantity, unit: unit)
            .statisticsIntervalSubtitlePhrase()
    }
}
