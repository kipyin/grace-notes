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

    func test_updateGratitude_unchangedText_returnsTrueWithoutReSummarizing() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("Family")
        let originalLabel = viewModel.gratitudes[0].chipLabel

        let result = await viewModel.updateGratitude(at: 0, fullText: "Family")

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Family")
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, originalLabel)
    }

    func test_updateGratitudeImmediate_updatesWithInterimLabel() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)
        viewModel.gratitudes = [JournalItem(fullText: "Old", chipLabel: "Old", isTruncated: false)]

        let longText = "A very long gratitude that exceeds twenty characters"
        let result = viewModel.updateGratitudeImmediate(at: 0, fullText: longText)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, longText)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, String(longText.prefix(20)))
        XCTAssertTrue(viewModel.gratitudes[0].isTruncated)
    }

    func test_addGratitudeImmediate_appendsWithInterimLabel() throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)

        let result = viewModel.addGratitudeImmediate("New gratitude")

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.gratitudes.count, 1)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "New gratitude")
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "New gratitude")
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

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
