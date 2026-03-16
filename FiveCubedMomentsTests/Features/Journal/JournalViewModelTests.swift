import XCTest
import SwiftData
@testable import FiveCubedMoments

@MainActor
final class JournalViewModelTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)
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
            gratitudes: [JournalItem(fullText: "Family", chipLabel: nil)],
            needs: [JournalItem(fullText: "Wisdom", chipLabel: nil)],
            people: [JournalItem(fullText: "Friend", chipLabel: nil)],
            bibleNotes: "Psalm 23",
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
        XCTAssertEqual(viewModel.bibleNotes, "Psalm 23")
        XCTAssertEqual(viewModel.reflections, "Trusting God")
    }

    func test_loadEntry_forPastDate_loadsExistingPastEntry() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200) // 2025-03-15
        let pastDate = Date(timeIntervalSince1970: 1_742_056_800) // 2025-03-04
        let startOfPastDay = calendar.startOfDay(for: pastDate)
        let pastEntry = JournalEntry(
            entryDate: startOfPastDay,
            gratitudes: [JournalItem(fullText: "Past gratitude", chipLabel: nil)],
            needs: [JournalItem(fullText: "Past need", chipLabel: nil)],
            people: [JournalItem(fullText: "Past person", chipLabel: nil)],
            bibleNotes: "Past notes",
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
        XCTAssertEqual(viewModel.bibleNotes, "Past notes")
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
            gratitudes: [JournalItem(fullText: "Today", chipLabel: nil)],
            needs: [],
            people: [],
            bibleNotes: "",
            reflections: "",
            createdAt: now,
            updatedAt: now
        )
        let pastEntry = JournalEntry(
            entryDate: startOfPastDay,
            gratitudes: [JournalItem(fullText: "Past", chipLabel: nil)],
            needs: [],
            people: [],
            bibleNotes: "",
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
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("  Family  ")
        await viewModel.addNeed("Peace")
        await viewModel.addPerson("Alice")
        await viewModel.addGratitude("   ") // whitespace-only should be rejected
        await viewModel.addNeed("") // empty should be rejected
        viewModel.updateBibleNotes("  Matthew 5  ")
        viewModel.updateReflections("  Be patient today  ")

        let payload = viewModel.exportSnapshot()

        XCTAssertEqual(payload.gratitudes, ["Family"])
        XCTAssertEqual(payload.needs, ["Peace"])
        XCTAssertEqual(payload.people, ["Alice"])
        XCTAssertEqual(payload.bibleNotes, "Matthew 5")
        XCTAssertEqual(payload.reflections, "Be patient today")
    }

    func test_exportSnapshot_partialEntry_producesValidPayload() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("One gratitude")

        let payload = viewModel.exportSnapshot()

        XCTAssertEqual(payload.gratitudes, ["One gratitude"])
        XCTAssertEqual(payload.needs, [])
        XCTAssertEqual(payload.people, [])
        XCTAssertTrue(payload.bibleNotes.isEmpty)
        XCTAssertTrue(payload.reflections.isEmpty)
        XCTAssertFalse(payload.dateFormatted.isEmpty)
    }

    func test_updateGratitudeRejectsEmptyString_leavesOriginalUnchanged() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("Family")
        await viewModel.updateGratitude(at: 0, fullText: "   ")

        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Family")
    }

    func test_updateNeedRejectsEmptyString_leavesOriginalUnchanged() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addNeed("Peace")
        await viewModel.updateNeed(at: 0, fullText: "")

        XCTAssertEqual(viewModel.needs[0].fullText, "Peace")
    }

    func test_updatePersonRejectsEmptyString_leavesOriginalUnchanged() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addPerson("Alice")
        await viewModel.updatePerson(at: 0, fullText: "\n\t")

        XCTAssertEqual(viewModel.people[0].fullText, "Alice")
    }

    func test_updatesPersistAfterDebouncedAutosave() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("  Family  ")
        await viewModel.addNeed("Peace")
        await viewModel.addPerson("Alice")
        viewModel.updateBibleNotes("  Matthew 5  ")
        viewModel.updateReflections("  Be patient today  ")

        try await Task.sleep(nanoseconds: 800_000_000)

        let descriptor = FetchDescriptor<JournalEntry>()
        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].gratitudes.map(\.fullText), ["Family"])
        XCTAssertEqual(entries[0].needs.map(\.fullText), ["Peace"])
        XCTAssertEqual(entries[0].people.map(\.fullText), ["Alice"])
        XCTAssertEqual(entries[0].bibleNotes, "Matthew 5")
        XCTAssertEqual(entries[0].reflections, "Be patient today")
    }

    func test_removeGratitude_validIndex_removesAndPersists() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("First")
        await viewModel.addGratitude("Second")

        let removed = viewModel.removeGratitude(at: 0)

        XCTAssertTrue(removed)
        XCTAssertEqual(viewModel.gratitudes.count, 1)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Second")
    }

    func test_removeGratitude_invalidIndex_returnsFalse() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)

        let removed = viewModel.removeGratitude(at: 99)

        XCTAssertFalse(removed)
        XCTAssertEqual(viewModel.gratitudes.count, 0)
    }

    func test_removeNeed_validIndex_removesAndPersists() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addNeed("Peace")
        await viewModel.addNeed("Joy")

        let removed = viewModel.removeNeed(at: 0)

        XCTAssertTrue(removed)
        XCTAssertEqual(viewModel.needs.count, 1)
        XCTAssertEqual(viewModel.needs[0].fullText, "Joy")
    }

    func test_removePerson_validIndex_removesAndPersists() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addPerson("Alice")
        await viewModel.addPerson("Bob")

        let removed = viewModel.removePerson(at: 1)

        XCTAssertTrue(removed)
        XCTAssertEqual(viewModel.people.count, 1)
        XCTAssertEqual(viewModel.people[0].fullText, "Alice")
    }

    func test_completedToday_withFullEntry_returnsTrue() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        for index in 1...5 {
            _ = await viewModel.addGratitude("Gratitude \(index)")
            _ = await viewModel.addNeed("Need \(index)")
            _ = await viewModel.addPerson("Person \(index)")
        }
        viewModel.updateBibleNotes("Psalm 23")
        viewModel.updateReflections("Today was meaningful")

        XCTAssertTrue(viewModel.completedToday)
    }

    func test_completedToday_withPartialEntry_returnsFalse() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        _ = await viewModel.addGratitude("One")
        _ = await viewModel.addNeed("One")
        _ = await viewModel.addPerson("One")
        viewModel.updateBibleNotes("Notes")
        viewModel.updateReflections("Reflections")

        XCTAssertFalse(viewModel.completedToday)
    }

    func test_addGratitude_atSlotLimit_returnsFalseAndDoesNotAdd() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        for index in 1...5 {
            _ = await viewModel.addGratitude("Gratitude \(index)")
        }
        let sixth = await viewModel.addGratitude("Sixth gratitude")

        XCTAssertFalse(sixth)
        XCTAssertEqual(viewModel.gratitudes.count, 5)
    }

    func test_addNeed_atSlotLimit_returnsFalseAndDoesNotAdd() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        for index in 1...5 {
            _ = await viewModel.addNeed("Need \(index)")
        }
        let sixth = await viewModel.addNeed("Sixth need")

        XCTAssertFalse(sixth)
        XCTAssertEqual(viewModel.needs.count, 5)
    }

    func test_addPerson_atSlotLimit_returnsFalseAndDoesNotAdd() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        for index in 1...5 {
            _ = await viewModel.addPerson("Person \(index)")
        }
        let sixth = await viewModel.addPerson("Sixth person")

        XCTAssertFalse(sixth)
        XCTAssertEqual(viewModel.people.count, 5)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
