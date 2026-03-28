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

    func test_hasHarvestChips_alignsWithFullLevel_withOrWithoutNotes() throws {
        let context = try makeInMemoryContext()
        let items = (1...JournalEntry.slotCount).map { JournalItem(fullText: "x\($0)", chipLabel: nil) }
        let harvestOnly = JournalEntry(
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "",
            reflections: ""
        )
        let harvestWithNotes = JournalEntry(
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "Notes",
            reflections: "Reflections"
        )
        context.insert(harvestOnly)
        context.insert(harvestWithNotes)
        try context.save()

        XCTAssertTrue(harvestOnly.hasHarvestChips)
        XCTAssertTrue(harvestOnly.isComplete)
        XCTAssertEqual(harvestOnly.completionLevel, .full)

        XCTAssertTrue(harvestWithNotes.hasHarvestChips)
        XCTAssertEqual(harvestWithNotes.completionLevel, .full)
    }

    func test_tutorialCompletionRank_isMonotonic() {
        XCTAssertEqual(JournalCompletionLevel.empty.tutorialCompletionRank, 0)
        XCTAssertEqual(JournalCompletionLevel.started.tutorialCompletionRank, 1)
        XCTAssertEqual(JournalCompletionLevel.growing.tutorialCompletionRank, 2)
        XCTAssertEqual(JournalCompletionLevel.balanced.tutorialCompletionRank, 3)
        XCTAssertEqual(JournalCompletionLevel.full.tutorialCompletionRank, 4)
    }

    func test_completionLevel_JSON_decodesLegacyRawStrings() throws {
        let decoder = JSONDecoder()
        let legacyPairs: [(String, JournalCompletionLevel)] = [
            ("soil", .empty),
            ("seed", .started),
            ("ripening", .balanced),
            ("harvest", .full),
            ("abundance", .full)
        ]
        for (raw, expected) in legacyPairs {
            let jsonString = "\"\(raw)\""
            let data = try XCTUnwrap(jsonString.data(using: .utf8))
            let decoded = try decoder.decode(JournalCompletionLevel.self, from: data)
            XCTAssertEqual(decoded, expected, raw)
        }
    }

    func test_completionLevel_JSON_encodesCurrentRawStrings() throws {
        let data = try JSONEncoder().encode(JournalCompletionLevel.balanced)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"balanced\"")
    }

    func test_hasMeaningfulContent_trueWhenOnlyReadingNotesOnEmptyChips() {
        let entry = JournalEntry(
            entryDate: .now,
            gratitudes: [],
            needs: [],
            people: [],
            readingNotes: "A verse stood out.",
            reflections: ""
        )
        XCTAssertEqual(entry.completionLevel, .empty)
        XCTAssertTrue(entry.hasMeaningfulContent)
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
