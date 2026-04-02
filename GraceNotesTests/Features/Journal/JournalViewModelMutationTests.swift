import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalViewModelMutationTests: XCTestCase {
    var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try skipIfKnownHostedSwiftDataCrash()
    }

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
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

    func test_updateGratitude_unchangedText_returnsTrueWithoutMutating() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("Family")
        let idBefore = viewModel.gratitudes[0].id

        let result = await viewModel.updateGratitude(at: 0, fullText: "Family")

        XCTAssertTrue(result)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "Family")
        XCTAssertEqual(viewModel.gratitudes[0].id, idBefore)
    }

    func test_updateGratitudeImmediate_keepsFullText() throws {
        try skipIfKnownHostedSwiftDataCrash()
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)
        viewModel.gratitudes = [JournalItem(fullText: "Old")]

        let longText = "A very long gratitude that exceeds twenty characters"
        let result = viewModel.updateGratitudeImmediate(at: 0, fullText: longText)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, longText)
    }

    func test_updatePersonImmediate_preservesMixedLanguageFullText() throws {
        try skipIfKnownHostedSwiftDataCrash()
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)
        viewModel.people = [JournalItem(fullText: "Old person")]

        let input = "为 Amy 祷告平安"
        let result = viewModel.updatePersonImmediate(at: 0, fullText: input)

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.people[0].fullText, input)
    }

    func test_addGratitudeImmediate_appendsFullText() throws {
        try skipIfKnownHostedSwiftDataCrash()
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = JournalViewModel(calendar: calendar, nowProvider: { now })

        viewModel.loadEntry(for: now, using: context)

        let result = viewModel.addGratitudeImmediate("New gratitude")

        XCTAssertEqual(result, 0)
        XCTAssertEqual(viewModel.gratitudes.count, 1)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "New gratitude")
    }
}
