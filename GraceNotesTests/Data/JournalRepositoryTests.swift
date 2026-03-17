import XCTest
import SwiftData
@testable import GraceNotes

@MainActor
final class JournalRepositoryTests: XCTestCase {
    private var calendar: Calendar!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try skipIfKnownHostedSwiftDataCrash()
    }

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func test_fetchAllEntries_returnsSortedByDateDescending() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)

        let date1 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_147_200)) // 2025-03-15
        let date2 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_056_800)) // 2025-03-04
        let date3 = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_742_221_600)) // 2025-03-22

        let entry1 = JournalEntry(entryDate: date1, createdAt: date1, updatedAt: date1)
        let entry2 = JournalEntry(entryDate: date2, createdAt: date2, updatedAt: date2)
        let entry3 = JournalEntry(entryDate: date3, createdAt: date3, updatedAt: date3)
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
        let entry = JournalEntry(
            entryDate: startOfDay,
            gratitudes: [JournalItem(fullText: "Test", chipLabel: nil)],
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
        XCTAssertEqual(result?.gratitudes.map(\.fullText), ["Test"])
    }

    func test_fetchEntry_forMissingDate_returnsNil() throws {
        let context = try makeInMemoryContext()
        let repo = JournalRepository(calendar: calendar)
        let now = Date(timeIntervalSince1970: 1_742_147_200)

        let result = try repo.fetchEntry(for: now, context: context)

        XCTAssertNil(result)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FiveCubedMomentsTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    private func skipIfKnownHostedSwiftDataCrash() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil else { return }
        throw XCTSkip("Skipping due to known hosted SwiftData malloc crash on current iOS simulator runtime.")
    }
}
