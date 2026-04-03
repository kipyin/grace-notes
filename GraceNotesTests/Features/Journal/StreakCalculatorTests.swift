import SwiftData
import XCTest
@testable import GraceNotes

final class StreakCalculatorTests: XCTestCase {
    private var calendar: Calendar!
    private var calculator: StreakCalculator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calculator = StreakCalculator(calendar: calendar)
    }

    func test_blankAutoCreatedEntry_doesNotCountAsBasicStreak() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let blankToday = makeEntry(on: date(year: 2026, month: 3, day: 17, hour: 8))

        let summary = calculator.summary(from: try persisted(context, blankToday), now: now)

        XCTAssertEqual(summary.basicCurrent, 0)
        XCTAssertEqual(summary.perfectCurrent, 0)
    }

    func test_partialEntry_countsAsBasicNotPerfect() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let partialToday = makeEntry(
            on: date(year: 2026, month: 3, day: 17, hour: 9),
            gratitudes: [Entry(fullText: "Family")]
        )

        let summary = calculator.summary(from: try persisted(context, partialToday), now: now)

        XCTAssertEqual(summary.basicCurrent, 1)
        XCTAssertEqual(summary.perfectCurrent, 0)
        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertFalse(summary.perfectDoneToday)
    }

    func test_readingNotesOnlyOnEmptyChips_countsAsBasicStreak() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let notesOnly = makeEntry(
            on: date(year: 2026, month: 3, day: 17, hour: 9),
            readingNotes: "A short note from this morning."
        )

        let summary = calculator.summary(from: try persisted(context, notesOnly), now: now)

        XCTAssertEqual(summary.basicCurrent, 1)
        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertEqual(summary.perfectCurrent, 0)
    }

    func test_fullGridEntry_countsAsBasicAndPerfect() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let completeToday = makeCompleteEntry(on: date(year: 2026, month: 3, day: 17, hour: 10))

        let summary = calculator.summary(from: try persisted(context, completeToday), now: now)

        XCTAssertEqual(summary.basicCurrent, 1)
        XCTAssertEqual(summary.perfectCurrent, 1)
        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertTrue(summary.perfectDoneToday)
    }

    func test_harvestOnlyWithoutNotes_countsAsBasicAndPerfect() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let day = date(year: 2026, month: 3, day: 17, hour: 10)
        let items = (1...Journal.slotCount).map { Entry(fullText: "Item \($0)") }
        let harvestOnly = makeEntry(
            on: day,
            gratitudes: items,
            needs: items,
            people: items
        )

        let summary = calculator.summary(from: try persisted(context, harvestOnly), now: now)

        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertTrue(summary.perfectDoneToday)
        XCTAssertEqual(summary.basicCurrent, 1)
        XCTAssertEqual(summary.perfectCurrent, 1)
    }

    func test_staleCompletedAt_doesNotInflatePerfectWithoutHarvestChips() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let day = date(year: 2026, month: 3, day: 17, hour: 9)
        let partial = makeEntry(
            on: day,
            gratitudes: [Entry(fullText: "One")],
            needs: [Entry(fullText: "One")],
            people: [Entry(fullText: "One")],
            completedAt: now
        )

        let summary = calculator.summary(from: try persisted(context, partial), now: now)

        XCTAssertTrue(summary.basicDoneToday)
        XCTAssertFalse(summary.perfectDoneToday)
        XCTAssertEqual(summary.perfectCurrent, 0)
    }

    func test_streakBreakAcrossSkippedDay_resetsCurrentStreak() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let twoDaysAgo = makeEntry(
            on: date(year: 2026, month: 3, day: 15, hour: 11),
            gratitudes: [Entry(fullText: "Grateful")]
        )

        let summary = calculator.summary(from: try persisted(context, twoDaysAgo), now: now)

        XCTAssertEqual(summary.basicCurrent, 0)
        XCTAssertEqual(summary.perfectCurrent, 0)
    }

    func test_dateNormalization_usesCalendarDayBoundaries() throws {
        let context = try makeInMemoryContext()
        let now = date(year: 2026, month: 3, day: 17, hour: 12)
        let lateYesterday = makeEntry(
            on: date(year: 2026, month: 3, day: 16, hour: 23, minute: 59),
            gratitudes: [Entry(fullText: "Late gratitude")],
            needs: [Entry(fullText: "Late need")],
            people: [Entry(fullText: "Late person")]
        )
        let earlyToday = makeEntry(
            on: date(year: 2026, month: 3, day: 17, hour: 0, minute: 1),
            gratitudes: [Entry(fullText: "Early gratitude")],
            needs: [Entry(fullText: "Early need")],
            people: [Entry(fullText: "Early person")]
        )

        let summary = calculator.summary(
            from: try persisted(context, lateYesterday, earlyToday),
            now: now
        )

        XCTAssertEqual(summary.basicCurrent, 2)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Journal.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesStreakTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    private func persisted(_ context: ModelContext, _ entries: Journal...) throws -> [Journal] {
        for entry in entries {
            context.insert(entry)
        }
        try context.save()
        return Array(entries)
    }

    private func makeEntry(
        on date: Date,
        gratitudes: [Entry] = [],
        needs: [Entry] = [],
        people: [Entry] = [],
        readingNotes: String = "",
        reflections: String = "",
        completedAt: Date? = nil
    ) -> Journal {
        Journal(
            entryDate: date,
            gratitudes: gratitudes,
            needs: needs,
            people: people,
            readingNotes: readingNotes,
            reflections: reflections,
            completedAt: completedAt
        )
    }

    private func makeCompleteEntry(on date: Date) -> Journal {
        let items = (1...Journal.slotCount).map {
            Entry(fullText: "Item \($0)")
        }
        return makeEntry(
            on: date,
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "Psalm 23",
            reflections: "Today was meaningful",
            completedAt: date
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
