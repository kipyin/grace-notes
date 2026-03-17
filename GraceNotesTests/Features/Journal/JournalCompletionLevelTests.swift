import XCTest
@testable import FiveCubedMoments

final class JournalCompletionLevelTests: XCTestCase {
    func test_completionLevel_none_whenEntryIsBlank() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 0,
            needsCount: 0,
            peopleCount: 0,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .none)
    }

    func test_completionLevel_quickCheckIn_withSingleGratitude() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 1,
            needsCount: 0,
            peopleCount: 0,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .quickCheckIn)
    }

    func test_completionLevel_standardReflection_withThreeByThreeByThree() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 3,
            needsCount: 3,
            peopleCount: 3,
            readingNotes: "",
            reflections: ""
        )

        XCTAssertEqual(level, .standardReflection)
    }

    func test_completionLevel_standardReflection_withMixedContent() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 2,
            needsCount: 2,
            peopleCount: 2,
            readingNotes: "A short note",
            reflections: ""
        )

        XCTAssertEqual(level, .standardReflection)
    }

    func test_completionLevel_fullFiveCubed_withCurrentFullCriteria() {
        let level = JournalEntry.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 5,
            readingNotes: "Reading notes",
            reflections: "Reflections"
        )

        XCTAssertEqual(level, .fullFiveCubed)
    }
}
