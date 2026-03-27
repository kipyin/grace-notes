import SwiftData
import XCTest
@testable import GraceNotes

final class JournalCompletionLevelTests: XCTestCase {
    func test_completionLevel_empty_whenEntryIsBlank() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 0,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .empty)
    }

    func test_completionLevel_started_withSingleGratitudeOnly() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 1,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .started)
    }

    func test_completionLevel_started_twoZeroZero() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 2,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .started)
    }

    func test_completionLevel_started_twoTwoTwo() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 2,
            needsCount: 2,
            peopleCount: 2
        )

        XCTAssertEqual(level, .started)
    }

    func test_completionLevel_started_oneOneOne() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 1,
            needsCount: 1,
            peopleCount: 1
        )

        XCTAssertEqual(level, .started)
    }

    func test_completionLevel_growing_fiveTwoThree() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 2,
            peopleCount: 3
        )

        XCTAssertEqual(level, .growing)
    }

    func test_completionLevel_growing_threeZeroZero() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 3,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .growing)
    }

    func test_completionLevel_growing_fiveTwoTwo() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 2,
            peopleCount: 2
        )

        XCTAssertEqual(level, .growing)
    }

    func test_completionLevel_balanced_fiveThreeThree() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 3,
            peopleCount: 3
        )

        XCTAssertEqual(level, .balanced)
    }

    func test_completionLevel_balanced_fiveFiveFour() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 4
        )

        XCTAssertEqual(level, .balanced)
    }

    func test_completionLevel_full_fiveFiveFive() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 5
        )

        XCTAssertEqual(level, .full)
    }

    func test_hasHarvestChips_and_hasAbundanceRhythm_alignWithLevels() throws {
        let context = try makeInMemoryContext()
        let items = (1...JournalEntry.slotCount).map { JournalItem(fullText: "x\($0)", chipLabel: nil) }
        let harvestOnly = JournalEntry(
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "",
            reflections: ""
        )
        let abundance = JournalEntry(
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "Notes",
            reflections: "Reflections"
        )
        context.insert(harvestOnly)
        context.insert(abundance)
        try context.save()

        XCTAssertTrue(harvestOnly.hasHarvestChips)
        XCTAssertTrue(harvestOnly.isComplete)
        XCTAssertFalse(harvestOnly.hasAbundanceRhythm)
        XCTAssertEqual(harvestOnly.completionLevel, .full)

        XCTAssertTrue(abundance.hasAbundanceRhythm)
        XCTAssertEqual(abundance.completionLevel, .full)
    }

    func test_tutorialCompletionRank_isMonotonic() {
        XCTAssertEqual(JournalCompletionLevel.empty.tutorialCompletionRank, 0)
        XCTAssertEqual(JournalCompletionLevel.started.tutorialCompletionRank, 1)
        XCTAssertEqual(JournalCompletionLevel.growing.tutorialCompletionRank, 2)
        XCTAssertEqual(JournalCompletionLevel.balanced.tutorialCompletionRank, 3)
        XCTAssertEqual(JournalCompletionLevel.full.tutorialCompletionRank, 4)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesCompletionLevelTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
