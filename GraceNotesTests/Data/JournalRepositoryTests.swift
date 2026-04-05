import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalRepositoryTests: XCTestCase {
    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    func test_fetchAllEntries_returnsSortedByDateDescending() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)

        let date1 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200)) // 2025-03-15
        let date2 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_056_800)) // 2025-03-04
        let date3 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_221_600)) // 2025-03-22

        let entry1 = Journal(entryDate: date1, createdAt: date1, updatedAt: date1)
        let entry2 = Journal(entryDate: date2, createdAt: date2, updatedAt: date2)
        let entry3 = Journal(entryDate: date3, createdAt: date3, updatedAt: date3)
        context.insert(entry1)
        context.insert(entry2)
        context.insert(entry3)
        try context.save()

        let entries = try repo.fetchAllEntries(context: context)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].entryDate, date3)
        XCTAssertEqual(entries[1].entryDate, date1)
        XCTAssertEqual(entries[2].entryDate, date2)
    }

    func test_fetchEntry_forExistingDate_returnsEntry() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let startOfDay = calendar.startOfDay(for: now)
        let entry = Journal(
            entryDate: startOfDay,
            gratitudes: [Entry(fullText: "Test")],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            createdAt: now,
            updatedAt: now
        )
        context.insert(entry)
        try context.save()

        let result = try repo.fetchEntry(for: now, context: context)

        XCTAssertNotNil(result)
        XCTAssertEqual((result?.gratitudes ?? []).map(\.fullText), ["Test"])
    }

    func test_fetchEntry_forMissingDate_returnsNil() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let now = Date(timeIntervalSince1970: 1_742_147_200)

        let result = try repo.fetchEntry(for: now, context: context)

        XCTAssertNil(result)
    }

    func test_fetchEntry_whenTwoRowsSameDay_picksStrongestCompletionRow() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let later = day.addingTimeInterval(3600)

        let emptyStub = Journal(
            entryDate: day,
            gratitudes: [],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            createdAt: day,
            updatedAt: later
        )
        let fullFromOtherDevice = Journal(
            entryDate: day,
            gratitudes: Self.fiveStubItems(prefix: "g"),
            needs: Self.fiveStubItems(prefix: "n"),
            people: Self.fiveStubItems(prefix: "p"),
            readingNotes: "",
            reflections: "",
            createdAt: day,
            updatedAt: day
        )
        context.insert(emptyStub)
        context.insert(fullFromOtherDevice)
        try context.save()

        let result = try repo.fetchEntry(for: day.addingTimeInterval(12 * 3600), context: context)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, fullFromOtherDevice.id)
        XCTAssertEqual((result?.gratitudes ?? []).count, 5)
        XCTAssertTrue(result?.hasReachedBloom ?? false)
    }

    func test_hasUserEverReachedBloom_trueWhenCompletedAtSet() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let entry = Journal(
            entryDate: day,
            gratitudes: [Entry(fullText: "a")],
            needs: [],
            people: [],
            completedAt: day
        )
        context.insert(entry)
        try context.save()

        XCTAssertTrue(try repo.hasUserEverReachedBloom(context: context))
    }

    func test_hasUserEverReachedBloom_trueWhenLegacyFullWithoutCompletedAt() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let entry = Journal(
            entryDate: day,
            gratitudes: Self.fiveStubItems(prefix: "g"),
            needs: Self.fiveStubItems(prefix: "n"),
            people: Self.fiveStubItems(prefix: "p"),
            completedAt: nil
        )
        context.insert(entry)
        try context.save()

        XCTAssertTrue(try repo.hasUserEverReachedBloom(context: context))
    }

    func test_hasUserEverReachedBloom_falseWhenNeverBloom() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let entry = Journal(
            entryDate: day,
            gratitudes: [Entry(fullText: "a")],
            needs: [],
            people: [],
            completedAt: nil
        )
        context.insert(entry)
        try context.save()

        XCTAssertFalse(try repo.hasUserEverReachedBloom(context: context))
    }

    func test_searchMatches_returnsChipAndNotesLines() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let day1 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let day2 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_056_800))

        let entry1 = Journal(
            entryDate: day1,
            gratitudes: [Entry(fullText: "Morning coffee ritual")],
            needs: [],
            people: [],
            readingNotes: "Psalm study notes",
            reflections: "",
            createdAt: day1,
            updatedAt: day1
        )
        let entry2 = Journal(
            entryDate: day2,
            gratitudes: [],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "Rest day reflection",
            createdAt: day2,
            updatedAt: day2
        )
        context.insert(entry1)
        context.insert(entry2)
        try context.save()

        let coffeeMatches = try repo.searchMatches(query: "coffee", context: context, maxRows: 50)
        XCTAssertEqual(coffeeMatches.count, 1)
        XCTAssertEqual(coffeeMatches[0].source, .gratitudes)
        XCTAssertEqual(coffeeMatches[0].content, "Morning coffee ritual")
        XCTAssertEqual(coffeeMatches[0].entryDate, day1)

        let psalmMatches = try repo.searchMatches(query: "psalm", context: context, maxRows: 50)
        XCTAssertEqual(psalmMatches.count, 1)
        XCTAssertEqual(psalmMatches[0].source, .readingNotes)

        let restMatches = try repo.searchMatches(query: "rest", context: context, maxRows: 50)
        XCTAssertEqual(restMatches.count, 1)
        XCTAssertEqual(restMatches[0].source, .reflections)

        let empty = try repo.searchMatches(query: "   ", context: context, maxRows: 50)
        XCTAssertTrue(empty.isEmpty)
    }

    func test_searchMatches_chipMatchUsesFullTextWhenLabelDiffers_andIdIsStable() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200))
        let entryId = UUID(uuidString: "A0A0A0A0-BBBB-4CCC-8DDD-111122223333")!
        let itemId = UUID(uuidString: "B1B1B1B1-BBBB-4CCC-8DDD-111122223333")!
        let entry = Journal(
            id: entryId,
            entryDate: day,
            gratitudes: [Entry(fullText: "Thankful for morning coffee", id: itemId)],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            createdAt: day,
            updatedAt: day
        )
        context.insert(entry)
        try context.save()

        let matches = try repo.searchMatches(query: "coffee", context: context, maxRows: 50)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].source, .gratitudes)
        XCTAssertEqual(matches[0].content, "Thankful for morning coffee")

        let expectedId = "\(entryId.uuidString)|gratitudes|\(itemId.uuidString)"
        XCTAssertEqual(matches[0].id, expectedId)

        let again = try repo.searchMatches(query: "coffee", context: context, maxRows: 50)
        XCTAssertEqual(again[0].id, matches[0].id)
    }

    func test_searchMatches_respectsMaxRows() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        for index in 0..<5 {
            let day = calendar.startOfDay(
                for: Date(timeIntervalSince1970: 1_742_147_200 + TimeInterval(index * 86_400))
            )
            let entry = Journal(
                entryDate: day,
                gratitudes: [Entry(fullText: "match token")],
                needs: [],
                people: [],
                readingNotes: "",
                reflections: "",
                createdAt: day,
                updatedAt: day
            )
            context.insert(entry)
        }
        try context.save()

        let matches = try repo.searchMatches(query: "match", context: context, maxRows: 2)
        XCTAssertEqual(matches.count, 2)
    }

    private static func fiveStubItems(prefix: String) -> [Entry] {
        (0..<5).map { Entry(fullText: "\(prefix)\($0)") }
    }

    private func makeInMemoryContext() throws -> ModelContext {
        try SwiftDataTestIsolation.makeModelContext()
    }
}
