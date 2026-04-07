import XCTest
@testable import GraceNotes

final class EntryRowTapDebounceTests: XCTestCase {
    func test_acceptsFirstTap() {
        var lastID: UUID?
        var lastDate: Date?
        let id = UUID()
        let firstDate = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: id,
                at: firstDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertEqual(lastID, id)
        XCTAssertEqual(lastDate, firstDate)
    }

    func test_rejectsSecondTapOnSameRowWithinInterval() {
        var lastID: UUID?
        var lastDate: Date?
        let id = UUID()
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = firstDate.addingTimeInterval(0.1)

        XCTAssertTrue(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: id,
                at: firstDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertFalse(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: id,
                at: secondDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertEqual(lastID, id)
        XCTAssertEqual(lastDate, firstDate)
    }

    func test_acceptsSecondTapOnSameRowAfterInterval() {
        var lastID: UUID?
        var lastDate: Date?
        let id = UUID()
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = firstDate.addingTimeInterval(0.4)

        XCTAssertTrue(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: id,
                at: firstDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertTrue(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: id,
                at: secondDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertEqual(lastID, id)
        XCTAssertEqual(lastDate, secondDate)
    }

    func test_acceptsTapOnDifferentRowImmediately() {
        var lastID: UUID?
        var lastDate: Date?
        let firstRowID = UUID()
        let secondRowID = UUID()
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = firstDate.addingTimeInterval(0.05)

        XCTAssertTrue(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: firstRowID,
                at: firstDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertTrue(
            EntryRowTapDebounce.shouldProcessTap(
                itemID: secondRowID,
                at: secondDate,
                lastAcceptedItemID: &lastID,
                lastAcceptedDate: &lastDate,
                interval: 0.35
            )
        )
        XCTAssertEqual(lastID, secondRowID)
        XCTAssertEqual(lastDate, secondDate)
    }
}
