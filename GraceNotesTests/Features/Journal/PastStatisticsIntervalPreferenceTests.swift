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

    func test_resolvedHistoryRange_allMode_futureOnlyEntries_doesNotTrapAndCapsLowerToReferenceDay() {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else {
            XCTFail("Missing UTC timezone")
            return
        }
        calendar.timeZone = utc
        let refStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let futureDay = calendar.date(byAdding: .day, value: 10, to: refStart)!
        let entries = [Journal(entryDate: futureDay, gratitudes: [Entry(fullText: "x")], needs: [], people: [])]
        let range = PastStatisticsIntervalSelection(mode: .all, quantity: 4, unit: .week)
            .resolvedHistoryRange(referenceDate: refStart, calendar: calendar, allEntries: entries)
        XCTAssertEqual(range.lowerBound, refStart)
        XCTAssertEqual(range.upperBound, calendar.date(byAdding: .day, value: 1, to: refStart))
    }
}
