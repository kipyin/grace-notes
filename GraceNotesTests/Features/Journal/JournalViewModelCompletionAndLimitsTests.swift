import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalViewModelCompletionAndLimitsTests: XCTestCase {
    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    func test_completedToday_withFullEntry_returnsTrue() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...JournalViewModel.slotCount {
            _ = await viewModel.addGratitude("Gratitude \(index)")
            _ = await viewModel.addNeed("Need \(index)")
            _ = await viewModel.addPerson("Person \(index)")
        }
        viewModel.updateReadingNotes("Psalm 23")
        viewModel.updateReflections("Today was meaningful")

        XCTAssertTrue(viewModel.completedToday)
    }

    func test_completedToday_withPartialEntry_returnsFalse() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        _ = await viewModel.addGratitude("One")
        _ = await viewModel.addNeed("One")
        _ = await viewModel.addPerson("One")
        viewModel.updateReadingNotes("Notes")
        viewModel.updateReflections("Reflections")

        XCTAssertFalse(viewModel.completedToday)
    }

    func test_completionLevel_withSingleSectionEntry_returnsStarted() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        _ = await viewModel.addGratitude("One")

        XCTAssertEqual(viewModel.completionLevel, .sprout)
        XCTAssertFalse(viewModel.completedToday)
    }

    func test_completionLevel_withThreeByThreeByThree_returnsBalanced() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...3 {
            _ = await viewModel.addGratitude("Gratitude \(index)")
            _ = await viewModel.addNeed("Need \(index)")
            _ = await viewModel.addPerson("Person \(index)")
        }

        XCTAssertEqual(viewModel.completionLevel, .leaf)
        XCTAssertFalse(viewModel.completedToday)
    }

    func test_isChipsFullGridComplete_withFiveByFiveByFive_returnsTrue() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...JournalViewModel.slotCount {
            _ = await viewModel.addGratitude("Gratitude \(index)")
            _ = await viewModel.addNeed("Need \(index)")
            _ = await viewModel.addPerson("Person \(index)")
        }

        XCTAssertTrue(viewModel.isChipsFullGridComplete)
        XCTAssertEqual(viewModel.chipsFilledCount, 15)
        XCTAssertEqual(
            viewModel.chipsProgressText,
            String(
                format: String(localized: "%d of %d"),
                locale: Locale.current,
                15,
                15
            )
        )
        XCTAssertEqual(viewModel.completionLevel, .bloom)
        XCTAssertTrue(viewModel.completedToday)
    }

    func test_isChipsFullGridComplete_withMissingChip_returnsFalse() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...JournalViewModel.slotCount {
            _ = await viewModel.addGratitude("Gratitude \(index)")
            _ = await viewModel.addNeed("Need \(index)")
        }
        for index in 1..<(JournalViewModel.slotCount) {
            _ = await viewModel.addPerson("Person \(index)")
        }

        XCTAssertFalse(viewModel.isChipsFullGridComplete)
        XCTAssertEqual(viewModel.chipsFilledCount, 14)
        XCTAssertEqual(
            viewModel.chipsProgressText,
            String(
                format: String(localized: "%d of %d"),
                locale: Locale.current,
                14,
                15
            )
        )
    }

    func test_addGratitude_atSlotLimit_returnsFalseAndDoesNotAdd() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...JournalViewModel.slotCount {
            _ = await viewModel.addGratitude("Gratitude \(index)")
        }
        let sixth = await viewModel.addGratitude("Sixth gratitude")

        XCTAssertFalse(sixth)
        XCTAssertEqual(viewModel.gratitudes.count, JournalViewModel.slotCount)
    }

    func test_addNeed_atSlotLimit_returnsFalseAndDoesNotAdd() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...JournalViewModel.slotCount {
            _ = await viewModel.addNeed("Need \(index)")
        }
        let sixth = await viewModel.addNeed("Sixth need")

        XCTAssertFalse(sixth)
        XCTAssertEqual(viewModel.needs.count, JournalViewModel.slotCount)
    }

    func test_addPerson_atSlotLimit_returnsFalseAndDoesNotAdd() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let viewModel = makeViewModel(now: now)

        viewModel.loadEntry(for: now, using: context)
        for index in 1...JournalViewModel.slotCount {
            _ = await viewModel.addPerson("Person \(index)")
        }
        let sixth = await viewModel.addPerson("Sixth person")

        XCTAssertFalse(sixth)
        XCTAssertEqual(viewModel.people.count, JournalViewModel.slotCount)
    }

    private func makeViewModel(now: Date) -> JournalViewModel {
        JournalViewModel(
            calendar: calendar,
            nowProvider: { now }
        )
    }

    private func makeInMemoryContext() throws -> ModelContext {
        try SwiftDataTestIsolation.makeModelContext()
    }
}
