import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalViewModelMutationTests: XCTestCase {
    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try skipIfKnownHostedSwiftDataCrash()
    }

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        UserDefaults.standard.set(false, forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.legacyCloudSummarizationKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        UserDefaults.standard.removeObject(forKey: AIFeaturesSettings.legacyCloudSummarizationKey)
        super.tearDown()
    }

    func test_updateGratitudeRejectsEmptyString_leavesOriginalUnchanged() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("Family")
        await viewModel.updateGratitude(at: 0, fullText: "   ")

        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Family")
    }

    func test_updateNeedRejectsEmptyString_leavesOriginalUnchanged() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addNeed("Peace")
        await viewModel.updateNeed(at: 0, fullText: "")

        XCTAssertEqual(viewModel.needs[0].fullText, "Peace")
    }

    func test_updatePersonRejectsEmptyString_leavesOriginalUnchanged() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addPerson("Alice")
        await viewModel.updatePerson(at: 0, fullText: "\n\t")

        XCTAssertEqual(viewModel.people[0].fullText, "Alice")
    }

    func test_updateGratitude_unchangedText_returnsTrueWithoutReSummarizing() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let spy = SpySummarizer()
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: spy)
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("Family")
        let callCountAfterAdd = spy.summarizeCallCount

        let result = await viewModel.updateGratitude(at: 0, fullText: "Family")

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Family")
        XCTAssertEqual(
            spy.summarizeCallCount,
            callCountAfterAdd,
            "Summarizer should not be called when text is unchanged"
        )
    }

    func test_updateGratitudeImmediate_updatesWithInterimLabel() throws {
        try skipIfKnownHostedSwiftDataCrash()
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)
        viewModel.gratitudes = [JournalItem(fullText: "Old", chipLabel: "Old", isTruncated: false)]

        let longText = "A very long gratitude that exceeds twenty characters"
        let result = viewModel.updateGratitudeImmediate(at: 0, fullText: longText)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, longText)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "\(String(longText.prefix(10)))...")
        XCTAssertTrue(viewModel.gratitudes[0].isTruncated)
    }

    func test_updatePersonImmediate_mixedLanguage_preservesLatinNameInChipLabel() throws {
        try skipIfKnownHostedSwiftDataCrash()
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)
        viewModel.people = [JournalItem(fullText: "Old person", chipLabel: "Old person", isTruncated: false)]

        let input = "为 Amy 祷告平安"
        let result = viewModel.updatePersonImmediate(at: 0, fullText: input)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.people[0].chipLabel, input)
        XCTAssertFalse(viewModel.people[0].isTruncated)
    }

    func test_addGratitudeImmediate_appendsWithInterimLabel() throws {
        try skipIfKnownHostedSwiftDataCrash()
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

    func test_renameGratitudeLabel_capsLabelAndPreservesFullText() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("I am grateful for my family.")

        let didRename = viewModel.renameGratitudeLabel(at: 0, to: "Family support always")

        XCTAssertTrue(didRename)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "I am grateful for my family.")
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "Family sup...")
        XCTAssertTrue(viewModel.gratitudes[0].isTruncated)
    }

    func test_renameNeedLabel_shortLabelClearsTruncation() throws {
        try skipIfKnownHostedSwiftDataCrash()
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        viewModel.needs = [JournalItem(fullText: "I need rest.", chipLabel: "Long label previously", isTruncated: true)]

        let didRename = viewModel.renameNeedLabel(at: 0, to: "Rest")

        XCTAssertTrue(didRename)
        XCTAssertEqual(viewModel.needs[0].chipLabel, "Rest")
        XCTAssertFalse(viewModel.needs[0].isTruncated)
    }

    func test_renameNeedLabel_rejectsWhitespaceLabel() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addNeed("I need quiet time.")
        let originalLabel = viewModel.needs[0].chipLabel

        let didRename = viewModel.renameNeedLabel(at: 0, to: " \n ")

        XCTAssertFalse(didRename)
        XCTAssertEqual(viewModel.needs[0].chipLabel, originalLabel)
    }

    func test_updateGratitudeImmediate_aiFeaturesEnabled_keepsFullLabelWithoutEllipsis() throws {
        try skipIfKnownHostedSwiftDataCrash()
        UserDefaults.standard.set(true, forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })
        let longText = "A very long gratitude that exceeds twenty characters"

        viewModel.loadEntry(for: now, using: context)
        viewModel.gratitudes = [JournalItem(fullText: "Old", chipLabel: "Old", isTruncated: false)]

        let result = viewModel.updateGratitudeImmediate(at: 0, fullText: longText)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, longText)
        XCTAssertFalse(viewModel.gratitudes[0].isTruncated)
    }

    func test_renameGratitudeLabel_aiFeaturesEnabled_keepsFullLabelWithoutEllipsis() async throws {
        UserDefaults.standard.set(true, forKey: AIFeaturesSettings.enabledUserDefaultsKey)
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("I am grateful for my family.")

        let didRename = viewModel.renameGratitudeLabel(at: 0, to: "Family support always")

        XCTAssertTrue(didRename)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "Family support always")
        XCTAssertFalse(viewModel.gratitudes[0].isTruncated)
    }

    func test_renamePersonLabel_whenUnchanged_returnsFalse() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addPerson("Pray for Alice this week")
        let existingLabel = viewModel.people[0].chipLabel ?? ""

        let didRename = viewModel.renamePersonLabel(at: 0, to: existingLabel)

        XCTAssertFalse(didRename)
        XCTAssertEqual(viewModel.people[0].chipLabel, existingLabel)
    }

    func test_removeGratitude_validIndex_removesAndPersists() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("First")
        await viewModel.addGratitude("Second")

        let removed = viewModel.removeGratitude(at: 0)

        XCTAssertTrue(removed)
        XCTAssertEqual(viewModel.gratitudes.count, 1)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Second")
    }

    func test_removeGratitude_invalidIndex_returnsFalse() throws {
        try skipIfKnownHostedSwiftDataCrash()
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
        let viewModel = makeViewModel(now: now)

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
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addPerson("Alice")
        await viewModel.addPerson("Bob")

        let removed = viewModel.removePerson(at: 1)

        XCTAssertTrue(removed)
        XCTAssertEqual(viewModel.people.count, 1)
        XCTAssertEqual(viewModel.people[0].fullText, "Alice")
    }

    func test_moveGratitude_validMove_reordersItems() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("First")
        await viewModel.addGratitude("Second")
        await viewModel.addGratitude("Third")

        let moved = viewModel.moveGratitude(from: 0, to: 3)

        XCTAssertTrue(moved)
        XCTAssertEqual(viewModel.gratitudes.map(\.fullText), ["Second", "Third", "First"])
    }

    func test_moveNeed_invalidDestination_returnsFalse() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addNeed("Need one")
        await viewModel.addNeed("Need two")

        let moved = viewModel.moveNeed(from: 1, to: 99)

        XCTAssertFalse(moved)
        XCTAssertEqual(viewModel.needs.map(\.fullText), ["Need one", "Need two"])
    }

    private func makeViewModel(now: Date) -> JournalViewModel {
        JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(fixedSummarizer: MockSummarizer())
        )
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    private func skipIfKnownHostedSwiftDataCrash() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil else { return }
        throw XCTSkip("Skipping due to known hosted SwiftData malloc crash on current iOS simulator runtime.")
    }
}
