import SwiftData
import XCTest
@testable import GraceNotes

final class WeeklyInsightRuleEngineTests: XCTestCase {
    private var calendar: Calendar!
    private var ruleEngine: WeeklyInsightRuleEngine!
    /// Retains the in-memory store for the duration of each `withPersisted*` closure (app-hosted SwiftData).
    private var persistedModelContainer: ModelContainer?

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        ruleEngine = WeeklyInsightRuleEngine()
    }

    func test_analyze_emptyWeek_returnsSparseFallbackInsight() {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let currentPeriod = ReviewInsightsPeriod.currentPeriod(
            containing: referenceDate,
            calendar: calendar
        )
        let analysis = ruleEngine.analyze(
            currentPeriod: currentPeriod,
            currentWeekEntries: [],
            previousWeekEntries: [],
            allEntries: [],
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(analysis.weeklyInsights.count, 1)
        XCTAssertEqual(analysis.weeklyInsights.first?.pattern, .sparseFallback)
    }

    func test_analyze_richSignal_limitsInsightsToTwo() throws {
        try withInsertedEntries { context in
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
            for entry in currentEntries {
                context.insert(entry)
            }
            try context.save()

            let referenceDate = date(year: 2026, month: 3, day: 19)
            let analysis = ruleEngine.analyze(
                currentPeriod: ReviewInsightsPeriod.currentPeriod(
                    containing: referenceDate,
                    calendar: calendar
                ),
                currentWeekEntries: currentEntries,
                previousWeekEntries: [],
                allEntries: currentEntries,
                calendar: calendar,
                referenceDate: referenceDate
            )
            XCTAssertLessThanOrEqual(analysis.weeklyInsights.count, 2)
        }
    }

    func test_analyze_detectsContinuityShiftAgainstPreviousWeek() throws {
        try withInsertedEntries { context in
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
            for entry in previousEntries + currentEntries {
                context.insert(entry)
            }
            try context.save()

            let referenceDate = date(year: 2026, month: 3, day: 19)
            let analysis = ruleEngine.analyze(
                currentPeriod: ReviewInsightsPeriod.currentPeriod(
                    containing: referenceDate,
                    calendar: calendar
                ),
                currentWeekEntries: currentEntries,
                previousWeekEntries: previousEntries,
                allEntries: previousEntries + currentEntries,
                calendar: calendar,
                referenceDate: referenceDate
            )

            let shift = analysis.weeklyInsights.first { $0.pattern == .continuityShift }
            XCTAssertNotNil(shift)
            XCTAssertTrue(shift?.observation.contains("Rest") == true)
            XCTAssertTrue(shift?.observation.contains("Family connection") == true)
        }
    }

    func test_analyze_detectsFullCompletionPattern_forSevenPerfectDays() throws {
        try withInsertedEntries { context in
            let currentEntries = (0...6).map { dayOffset in
                makeFullEntry(on: date(year: 2026, month: 3, day: 16 + dayOffset))
            }
            for entry in currentEntries {
                context.insert(entry)
            }
            try context.save()

            let referenceDate = date(year: 2026, month: 3, day: 18)
            let analysis = ruleEngine.analyze(
                currentPeriod: ReviewInsightsPeriod.currentPeriod(
                    containing: referenceDate,
                    calendar: calendar
                ),
                currentWeekEntries: currentEntries,
                previousWeekEntries: [],
                allEntries: currentEntries,
                calendar: calendar,
                referenceDate: referenceDate
            )

            let completion = analysis.weeklyInsights.first { $0.pattern == .fullCompletion }
            XCTAssertNotNil(completion)
            XCTAssertEqual(completion?.dayCount, 7)
        }
    }

    /// Surface text counts as a reflection day for `.empty` chip status (no chips filled).
    func test_analyze_soilEntryWithSurfaceText_usesNonEmptySparseFallbackWhenWeekIsSparse() throws {
        try withInsertedEntries { context in
            let entries = [
                makeEntry(
                    on: date(year: 2026, month: 3, day: 17),
                    readingNotes: String(repeating: "n", count: 39)
                )
            ]
            for entry in entries {
                context.insert(entry)
            }
            try context.save()

            let referenceDate = date(year: 2026, month: 3, day: 18)
            let analysis = ruleEngine.analyze(
                currentPeriod: ReviewInsightsPeriod.currentPeriod(
                    containing: referenceDate,
                    calendar: calendar
                ),
                currentWeekEntries: entries,
                previousWeekEntries: [],
                allEntries: entries,
                calendar: calendar,
                referenceDate: referenceDate
            )

            XCTAssertEqual(analysis.weeklyInsights.count, 1)
            let insight = analysis.weeklyInsights[0]
            XCTAssertEqual(insight.pattern, .sparseFallback)
            XCTAssertEqual(insight.dayCount, 1)
            XCTAssertEqual(analysis.weekStats.reflectionDays, 1)
            XCTAssertEqual(analysis.presentationMode, .statsFirst)
            XCTAssertNotEqual(
                insight.observation,
                "Start with one reflection today to build your weekly review.",
                "Sparse week with reflection surface text should not use the empty-week starter observation."
            )
        }
    }

    private func makeInMemoryContainerAndContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([JournalEntry.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesWeeklyInsightRuleTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return (container, ModelContext(container))
    }

    /// In-memory stack exists before building `@Model` rows (chip payloads), same idea as `StreakCalculatorTests`.
    private func withInsertedEntries<T>(
        _ run: (ModelContext) throws -> T
    ) throws -> T {
        let (container, context) = try makeInMemoryContainerAndContext()
        persistedModelContainer = container
        defer { persistedModelContainer = nil }
        return try run(context)
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
