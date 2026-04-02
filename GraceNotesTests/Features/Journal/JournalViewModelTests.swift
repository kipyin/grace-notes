import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalViewModelTests: XCTestCase {
    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    func test_loadTodayIfNeeded_createsSingleNormalizedEntry() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200) // 2025-03-15 12:00:00 UTC
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadTodayIfNeeded(using: context)
        viewModel.loadTodayIfNeeded(using: context)

        let startOfDay = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { entry in
                entry.entryDate >= startOfDay && entry.entryDate < nextDay
            }
        )

        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].entryDate, startOfDay)
    }

    func test_loadEntry_usesExistingEntryForSameDay() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let startOfDay = calendar.startOfDay(for: now)
        let existingEntry = JournalEntry(
            entryDate: startOfDay,
            gratitudes: [JournalItem(fullText: "Family")],
            needs: [JournalItem(fullText: "Wisdom")],
            people: [JournalItem(fullText: "Friend")],
            readingNotes: "Psalm 23",
            reflections: "Trusting God",
            createdAt: now,
            updatedAt: now
        )
        context.insert(existingEntry)
        try context.save()

        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })
        viewModel.loadEntry(for: now, using: context)

        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Family")
        XCTAssertEqual(viewModel.needs[0].fullText, "Wisdom")
        XCTAssertEqual(viewModel.people[0].fullText, "Friend")
        XCTAssertEqual(viewModel.readingNotes, "Psalm 23")
        XCTAssertEqual(viewModel.reflections, "Trusting God")
    }

    func test_loadEntry_forPastDate_loadsExistingPastEntry() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200) // 2025-03-15
        let pastDate = Date(timeIntervalSince1970: 1_742_056_800) // 2025-03-04
        let startOfPastDay = calendar.startOfDay(for: pastDate)
        let pastEntry = JournalEntry(
            entryDate: startOfPastDay,
            gratitudes: [JournalItem(fullText: "Past gratitude")],
            needs: [JournalItem(fullText: "Past need")],
            people: [JournalItem(fullText: "Past person")],
            readingNotes: "Past notes",
            reflections: "Past reflection",
            createdAt: pastDate,
            updatedAt: pastDate
        )
        context.insert(pastEntry)
        try context.save()

        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })
        viewModel.loadEntry(for: pastDate, using: context)

        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Past gratitude")
        XCTAssertEqual(viewModel.needs[0].fullText, "Past need")
        XCTAssertEqual(viewModel.people[0].fullText, "Past person")
        XCTAssertEqual(viewModel.readingNotes, "Past notes")
        XCTAssertEqual(viewModel.reflections, "Past reflection")
    }

    func test_loadEntry_switchingDates_hydratesCorrectly() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let pastDate = Date(timeIntervalSince1970: 1_742_056_800)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfPastDay = calendar.startOfDay(for: pastDate)

        let todayEntry = JournalEntry(
            entryDate: startOfToday,
            gratitudes: [JournalItem(fullText: "Today")],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            createdAt: now,
            updatedAt: now
        )
        let pastEntry = JournalEntry(
            entryDate: startOfPastDay,
            gratitudes: [JournalItem(fullText: "Past")],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            createdAt: pastDate,
            updatedAt: pastDate
        )
        context.insert(todayEntry)
        context.insert(pastEntry)
        try context.save()

        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })
        viewModel.loadTodayIfNeeded(using: context)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Today")

        viewModel.loadEntry(for: pastDate, using: context)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Past")
    }

    func test_exportSnapshot_trimsTextFromFieldsAndOmitsEmptySubmissions() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadEntry(for: now, using: context)
        _ = await viewModel.addGratitude("  Family  ")
        _ = await viewModel.addNeed("Peace")
        _ = await viewModel.addPerson("Alice")
        _ = await viewModel.addGratitude("   ") // whitespace-only should be rejected
        _ = await viewModel.addNeed("") // empty should be rejected
        viewModel.updateReadingNotes("  Matthew 5  ")
        viewModel.updateReflections("  Be patient today  ")

        let payload = viewModel.exportSnapshot()

        XCTAssertEqual(payload.gratitudes, ["Family"])
        XCTAssertEqual(payload.needs, ["Peace"])
        XCTAssertEqual(payload.people, ["Alice"])
        XCTAssertEqual(payload.readingNotes, "Matthew 5")
        XCTAssertEqual(payload.reflections, "Be patient today")
    }

    func test_exportSnapshot_partialEntry_producesValidPayload() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadEntry(for: now, using: context)
        _ = await viewModel.addGratitude("One gratitude")

        let payload = viewModel.exportSnapshot()

        XCTAssertEqual(payload.gratitudes, ["One gratitude"])
        XCTAssertEqual(payload.needs, [])
        XCTAssertEqual(payload.people, [])
        XCTAssertTrue(payload.readingNotes.isEmpty)
        XCTAssertTrue(payload.reflections.isEmpty)
        XCTAssertFalse(payload.dateFormatted.isEmpty)
    }

    func test_updatesPersistAfterDebouncedAutosave() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            autosaveDebounceMilliseconds: 50
        )

        viewModel.loadEntry(for: now, using: context)
        _ = await viewModel.addGratitude("  Family  ")
        _ = await viewModel.addNeed("Peace")
        _ = await viewModel.addPerson("Alice")
        viewModel.updateReadingNotes("  Matthew 5  ")
        viewModel.updateReflections("  Be patient today  ")

        try await Task.sleep(nanoseconds: 120_000_000)

        let descriptor = FetchDescriptor<JournalEntry>()
        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual((entries[0].gratitudes ?? []).map(\.fullText), ["Family"])
        XCTAssertEqual((entries[0].needs ?? []).map(\.fullText), ["Peace"])
        XCTAssertEqual((entries[0].people ?? []).map(\.fullText), ["Alice"])
        XCTAssertEqual(entries[0].readingNotes, "Matthew 5")
        XCTAssertEqual(entries[0].reflections, "Be patient today")
    }

    private func makeInMemoryContext() throws -> ModelContext {
        try SwiftDataTestIsolation.makeModelContext()
    }
}
