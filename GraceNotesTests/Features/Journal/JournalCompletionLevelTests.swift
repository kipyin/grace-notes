import SwiftData
import XCTest
@testable import GraceNotes

final class JournalCompletionLevelTests: XCTestCase {
    func test_completionLevel_soil_whenEntryIsBlank() {
        let level = Journal.completionLevel(
            gratitudesCount: 0,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .soil)
    }

    func test_completionLevel_sprout_withSingleGratitudeOnly() {
        let level = Journal.completionLevel(
            gratitudesCount: 1,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .sprout)
    }

    func test_completionLevel_sprout_twoZeroZero() {
        let level = Journal.completionLevel(
            gratitudesCount: 2,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .sprout)
    }

    func test_completionLevel_sprout_twoTwoTwo() {
        let level = Journal.completionLevel(
            gratitudesCount: 2,
            needsCount: 2,
            peopleCount: 2
        )

        XCTAssertEqual(level, .sprout)
    }

    func test_completionLevel_sprout_oneOneOne() {
        let level = Journal.completionLevel(
            gratitudesCount: 1,
            needsCount: 1,
            peopleCount: 1
        )

        XCTAssertEqual(level, .sprout)
    }

    func test_completionLevel_twig_fiveTwoThree() {
        let level = Journal.completionLevel(
            gratitudesCount: 5,
            needsCount: 2,
            peopleCount: 3
        )

        XCTAssertEqual(level, .twig)
    }

    func test_completionLevel_twig_threeZeroZero() {
        let level = Journal.completionLevel(
            gratitudesCount: 3,
            needsCount: 0,
            peopleCount: 0
        )

        XCTAssertEqual(level, .twig)
    }

    func test_completionLevel_twig_fiveTwoTwo() {
        let level = Journal.completionLevel(
            gratitudesCount: 5,
            needsCount: 2,
            peopleCount: 2
        )

        XCTAssertEqual(level, .twig)
    }

    func test_completionLevel_leaf_fiveThreeThree() {
        let level = Journal.completionLevel(
            gratitudesCount: 5,
            needsCount: 3,
            peopleCount: 3
        )

        XCTAssertEqual(level, .leaf)
    }

    func test_completionLevel_leaf_fiveFiveFour() {
        let level = Journal.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 4
        )

        XCTAssertEqual(level, .leaf)
    }

    func test_completionLevel_bloom_fiveFiveFive() {
        let level = Journal.completionLevel(
            gratitudesCount: 5,
            needsCount: 5,
            peopleCount: 5
        )

        XCTAssertEqual(level, .bloom)
    }

    func test_hasHarvestChips_alignsWithBloomLevel_withOrWithoutNotes() throws {
        let context = try makeInMemoryContext()
        let items = (1...Journal.slotCount).map { Entry(fullText: "x\($0)") }
        let harvestOnly = Journal(
            gratitudes: items,
            needs: items,
            people: items,
            readingNotes: "",
            reflections: ""
        )
        let harvestWithNotes = Journal(
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
        XCTAssertEqual(harvestOnly.completionLevel, .bloom)

        XCTAssertTrue(harvestWithNotes.hasHarvestChips)
        XCTAssertEqual(harvestWithNotes.completionLevel, .bloom)
    }

    func test_tutorialCompletionRank_isMonotonic() {
        XCTAssertEqual(JournalCompletionLevel.soil.tutorialCompletionRank, 0)
        XCTAssertEqual(JournalCompletionLevel.sprout.tutorialCompletionRank, 1)
        XCTAssertEqual(JournalCompletionLevel.twig.tutorialCompletionRank, 2)
        XCTAssertEqual(JournalCompletionLevel.leaf.tutorialCompletionRank, 3)
        XCTAssertEqual(JournalCompletionLevel.bloom.tutorialCompletionRank, 4)
    }

    func test_completionLevel_JSON_decodesLegacyRawStrings() throws {
        let decoder = JSONDecoder()
        let legacyPairs: [(String, JournalCompletionLevel)] = [
            ("empty", .soil),
            ("started", .sprout),
            ("seed", .sprout),
            ("growing", .twig),
            ("balanced", .leaf),
            ("ripening", .leaf),
            ("full", .bloom),
            ("harvest", .bloom),
            ("abundance", .bloom),
            ("soil", .soil),
            ("sprout", .sprout),
            ("twig", .twig),
            ("leaf", .leaf),
            ("bloom", .bloom)
        ]
        for (raw, expected) in legacyPairs {
            let jsonString = "\"\(raw)\""
            let data = try XCTUnwrap(jsonString.data(using: .utf8))
            let decoded = try decoder.decode(JournalCompletionLevel.self, from: data)
            XCTAssertEqual(decoded, expected, raw)
        }
    }

    func test_completionLevel_JSON_encodesCurrentRawStrings() throws {
        let data = try JSONEncoder().encode(JournalCompletionLevel.leaf)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"leaf\"")
    }

    func test_hasMeaningfulContent_trueWhenOnlyReadingNotesOnEmptyStrips() {
        let entry = Journal(
            entryDate: .now,
            gratitudes: [],
            needs: [],
            people: [],
            readingNotes: "A verse stood out.",
            reflections: ""
        )
        XCTAssertEqual(entry.completionLevel, .soil)
        XCTAssertTrue(entry.hasMeaningfulContent)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Journal.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesCompletionLevelTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
