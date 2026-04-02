import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
extension JournalViewModelMutationTests {
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

    func makeViewModel(now: Date) -> JournalViewModel {
        JournalViewModel(
            calendar: calendar,
            nowProvider: { now }
        )
    }

    func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    func skipIfKnownHostedSwiftDataCrash() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil else { return }
        throw XCTSkip("Skipping due to known hosted SwiftData malloc crash on current iOS simulator runtime.")
    }
}
