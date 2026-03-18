import XCTest
@testable import GraceNotes

final class WeeklyInsightRuleEngineTests: XCTestCase {
    private var calendar: Calendar!
    private var ruleEngine: WeeklyInsightRuleEngine!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        ruleEngine = WeeklyInsightRuleEngine()
    }

    func test_analyze_emptyWeek_returnsSparseFallbackInsight() {
        let analysis = ruleEngine.analyze(
            currentWeekEntries: [],
            previousWeekEntries: [],
            calendar: calendar
        )

        XCTAssertEqual(analysis.weeklyInsights.count, 1)
        XCTAssertEqual(analysis.weeklyInsights.first?.pattern, .sparseFallback)
    }

    func test_analyze_richSignal_limitsInsightsToTwo() {
        let currentEntries = [
            makeEntry(
                on: date(year: 2026, month: 3, day: 17),
                gratitudes: ["Family"],
                needs: ["Rest"],
                people: ["Mia"],
                readingNotes: "Rest came up in reading notes",
                reflections: "I need better rest and clear boundaries."
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 18),
                gratitudes: ["Family"],
                needs: ["Rest"],
                people: ["Mia"],
                readingNotes: "Still thinking about rest",
                reflections: "Mia was on my mind and I need rest."
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 19),
                gratitudes: ["Family"],
                needs: ["Rest"],
                people: ["Mia"],
                readingNotes: "",
                reflections: "Rest is a recurring need."
            )
        ]

        let analysis = ruleEngine.analyze(
            currentWeekEntries: currentEntries,
            previousWeekEntries: [],
            calendar: calendar
        )

        XCTAssertLessThanOrEqual(analysis.weeklyInsights.count, 2)
    }

    func test_analyze_detectsContinuityShiftAgainstPreviousWeek() {
        let previousEntries = [
            makeEntry(on: date(year: 2026, month: 3, day: 9), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 11), needs: ["Rest"])
        ]
        let currentEntries = [
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["Family connection"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), gratitudes: ["Family connection"]),
            makeEntry(on: date(year: 2026, month: 3, day: 19), gratitudes: ["Family connection"])
        ]

        let analysis = ruleEngine.analyze(
            currentWeekEntries: currentEntries,
            previousWeekEntries: previousEntries,
            calendar: calendar
        )

        let shift = analysis.weeklyInsights.first { $0.pattern == .continuityShift }
        XCTAssertNotNil(shift)
        XCTAssertTrue(shift?.observation.contains("Rest") == true)
        XCTAssertTrue(shift?.observation.contains("Family connection") == true)
    }

    func test_analyze_detectsFullCompletionPattern_forSevenPerfectDays() {
        let currentEntries = (0...6).map { dayOffset in
            makeFullEntry(on: date(year: 2026, month: 3, day: 16 + dayOffset))
        }

        let analysis = ruleEngine.analyze(
            currentWeekEntries: currentEntries,
            previousWeekEntries: [],
            calendar: calendar
        )

        let completion = analysis.weeklyInsights.first { $0.pattern == .fullCompletion }
        XCTAssertNotNil(completion)
        XCTAssertEqual(completion?.dayCount, 7)
    }

    private func makeEntry(
        on date: Date,
        gratitudes: [String] = [],
        needs: [String] = [],
        people: [String] = [],
        readingNotes: String = "",
        reflections: String = ""
    ) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: gratitudes.map { JournalItem(fullText: $0, chipLabel: $0) },
            needs: needs.map { JournalItem(fullText: $0, chipLabel: $0) },
            people: people.map { JournalItem(fullText: $0, chipLabel: $0) },
            readingNotes: readingNotes,
            reflections: reflections
        )
    }

    private func makeFullEntry(on date: Date) -> JournalEntry {
        let gratitudes = (1...5).map { JournalItem(fullText: "Gratitude \($0)", chipLabel: "Gratitude \($0)") }
        let needs = (1...5).map { JournalItem(fullText: "Need \($0)", chipLabel: "Need \($0)") }
        let people = (1...5).map { JournalItem(fullText: "Person \($0)", chipLabel: "Person \($0)") }
        return JournalEntry(
            entryDate: date,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: "Reading notes",
            reflections: "Reflections"
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
