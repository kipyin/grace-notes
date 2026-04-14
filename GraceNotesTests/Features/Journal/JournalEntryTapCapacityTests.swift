import SwiftUI
import XCTest
@testable import GraceNotes

@MainActor
final class JournalEntryTapCapacityTests: XCTestCase {
    func test_performEntryTap_whenAtCapacityWithDraftNotEditing_doesNotSwitchToTappedStrip() {
        var input = "Unsaved inline draft"
        var editingIndex: Int?
        var isTransitioning = false
        var didAdd = false
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in
                didAdd = true
                return nil
            },
            remove: { _ in false },
            fullText: { index in
                index == 1 ? "Other strip text" : "First strip"
            },
            count: JournalViewModel.slotCount
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "Unsaved inline draft")
        XCTAssertNil(editingIndex)
        XCTAssertFalse(didAdd)
    }

    func test_performEntryTap_whenBelowCapacityButAddFails_doesNotSwitchToTappedStrip() {
        var input = "Draft"
        var editingIndex: Int?
        var isTransitioning = false
        var addCallCount = 0
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in
                addCallCount += 1
                return nil
            },
            remove: { _ in false },
            fullText: { _ in "Would load if switched" },
            count: JournalViewModel.slotCount - 1
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 0,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "Draft")
        XCTAssertNil(editingIndex)
        XCTAssertEqual(addCallCount, 1)
    }
}
