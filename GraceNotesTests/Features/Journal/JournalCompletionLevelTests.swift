import SwiftData
import XCTest
@testable import GraceNotes

final class JournalCompletionLevelTests: XCTestCase {
    func test_completionLevel_soil_whenEntryIsBlank() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 0,
            needsCount: 0,
            peopleCount: 0,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .soil)
    }

    func test_completionLevel_soil_withSingleGratitudeOnly() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 1,
            needsCount: 0,
            peopleCount: 0,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .soil)
    }

    func test_completionLevel_ripening_withThreeByThreeByThree() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 3,
            needsCount: 3,
            peopleCount: 3,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .ripening)
    }

    func test_completionLevel_soil_withMixedContentButMissingOneChipSection() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 2,
            needsCount: 2,
            peopleCount: 0,
            readingNotes: "A short note",
            reflections: ""
        )

        XCTAssertEqual(level, .soil)
    }

    func test_completionLevel_seed_withOneGratitudeOneNeedAndOnePerson() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 1,
            needsCount: 1,
            peopleCount: 1,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .seed)
    }

    func test_completionLevel_seed_withWeakestSectionTwo() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 2,
            peopleCount: 3,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .seed)
    }

    func test_completionLevel_harvest_withFiveByFiveByFiveOnly() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 5,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .harvest)
    }

    func test_completionLevel_abundance_withCurrentFullCriteria() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 5,
            readingNotes: "Reading notes",
            reflections: "Reflections"
        )

        XCTAssertEqual(level, .abundance)
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
        XCTAssertEqual(harvestOnly.completionLevel, .harvest)

        XCTAssertTrue(abundance.hasAbundanceRhythm)
        XCTAssertEqual(abundance.completionLevel, .abundance)
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
