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
}
