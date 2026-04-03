import SwiftUI
import XCTest
@testable import GraceNotes

@MainActor
final class JournalScreenEntryHandlingTests: XCTestCase {
    func test_performEntryTap_whenEditingUnchangedText_switchesWithoutCommitting() {
        var input = "Current full text"
        var editingIndex: Int? = 0
        var isTransitioning = false
        var didUpdate = false
        var didAdd = false

        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in
                didUpdate = true
                return 0
            },
            addImmediate: { _ in
                didAdd = true
                return 1
            },
            remove: { _ in false },
            fullText: { index in
                index == 0 ? "Current full text" : "Tapped full text"
            },
            count: 2
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertFalse(didUpdate)
        XCTAssertFalse(didAdd)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Tapped full text")
    }

    func test_performEntryTap_whenEditingChangedText_commitsAndSwitchesStrip() {
        var input = "Edited text"
        var editingIndex: Int? = 0
        var isTransitioning = false

        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in 0 },
            addImmediate: { _ in nil },
            remove: { _ in false },
            fullText: { index in
                index == 0 ? "Original" : "Target full text"
            },
            count: 2
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Target full text")
    }

    func test_performEntryTap_whenTransitionInFlight_ignoresTap() {
        var input = "Draft text"
        var editingIndex: Int? = 0
        var isTransitioning = true

        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in 0 },
            addImmediate: { _ in 1 },
            remove: { _ in false },
            fullText: { _ in "Target full text" },
            count: 1
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 0,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertFalse(handled)
        XCTAssertEqual(input, "Draft text")
        XCTAssertEqual(editingIndex, 0)
    }

    func test_performDelete_whenDeletingEarlierItem_shiftsEditingIndex() {
        var input = "In progress"
        var editingIndex: Int? = 3

        JournalScreenEntryHandling.performDelete(
            index: 1,
            remove: { _ in true },
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertEqual(editingIndex, 2)
        XCTAssertEqual(input, "In progress")
    }

    func test_submitEntrySection_whenAddSucceeds_clearsInput() {
        var input = "New text"
        var editingIndex: Int?
        var isTransitioning = false
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in 2 },
            remove: { _ in false },
            fullText: { _ in nil },
            count: 2
        )

        let didSubmit = JournalScreenEntryHandling.submitEntrySection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(didSubmit)
        XCTAssertNil(editingIndex)
        XCTAssertEqual(input, "")
    }

    func test_submitEntrySection_whenTransitionInFlight_ignoresDuplicateSubmit() {
        var input = "New text"
        var editingIndex: Int?
        var isTransitioning = true
        var didAdd = false
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in
                didAdd = true
                return 0
            },
            remove: { _ in false },
            fullText: { _ in nil },
            count: 0
        )

        let didSubmit = JournalScreenEntryHandling.submitEntrySection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertFalse(didSubmit)
        XCTAssertFalse(didAdd)
        XCTAssertEqual(input, "New text")
    }

    func test_handleAddEntryTap_withActiveDraft_commitsAndStartsFreshInput() {
        var input = "Keep this draft"
        var editingIndex: Int? = 1
        var isTransitioning = false
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in 1 },
            addImmediate: { _ in nil },
            remove: { _ in false },
            fullText: { _ in nil },
            count: 2
        )

        let handled = JournalScreenEntryHandling.handleAddEntryTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
    }

    func test_handleAddEntryTap_withEmptyDraft_exitsEditingMode() {
        var input = "   "
        var editingIndex: Int? = 2
        var isTransitioning = false
        var didRemove = false
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in nil },
            remove: { index in
                didRemove = index == 2
                return index == 2
            },
            fullText: { _ in nil },
            count: 2
        )

        let handled = JournalScreenEntryHandling.handleAddEntryTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertTrue(didRemove)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
    }
}

extension JournalScreenEntryHandlingTests {
    func test_performEntryTap_withEmptyInlineEdit_opensTappedStripAfterDelete() {
        var input = "  \n"
        var editingIndex: Int? = 0
        var isTransitioning = false
        var removedIndex: Int?
        var chipTexts = ["First", "Second"]
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in nil },
            remove: { index in
                removedIndex = index
                guard index == 0 else { return false }
                chipTexts.remove(at: 0)
                return true
            },
            fullText: { index in
                guard chipTexts.indices.contains(index) else { return nil }
                return chipTexts[index]
            },
            count: 2
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(removedIndex, 0)
        XCTAssertEqual(editingIndex, 0)
        XCTAssertEqual(input, "Second")
    }

    func test_performEntryTap_withEmptyInlineEdit_tappingSameStrip_clearsEditing() {
        var input = ""
        var editingIndex: Int? = 1
        var isTransitioning = false
        var removedIndex: Int?
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in nil },
            remove: { index in
                removedIndex = index
                return index == 1
            },
            fullText: { index in
                index == 1 ? "Only" : "Other"
            },
            count: 2
        )

        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(removedIndex, 1)
        XCTAssertNil(editingIndex)
        XCTAssertEqual(input, "")
    }

    func test_handleAddEntryTap_whenNotEditingWithDraft_addsDraftAndStartsFreshInput() {
        var input = "New draft"
        var editingIndex: Int?
        var isTransitioning = false
        let operations = EntrySectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in 2 },
            remove: { _ in false },
            fullText: { _ in nil },
            count: 2
        )

        let handled = JournalScreenEntryHandling.handleAddEntryTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
    }

    func test_performMove_whenEditingMovedItem_updatesEditingIndexToDestination() {
        var editingIndex: Int? = 0

        JournalScreenEntryHandling.performMove(
            from: 0,
            to: 3,
            move: { _, _ in true },
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertEqual(editingIndex, 2)
    }

    func test_performMove_whenEditingItemBetweenRange_shiftsEditingIndex() {
        var editingIndex: Int? = 2

        JournalScreenEntryHandling.performMove(
            from: 0,
            to: 3,
            move: { _, _ in true },
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertEqual(editingIndex, 1)
    }
}

@MainActor
final class EntryReorderDropDelegateTests: XCTestCase {
    func test_applyLiveReorder_movesWhenDraggingOverDifferentChip() {
        let first = Entry(fullText: "First")
        let second = Entry(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID?
        var moveCount = 0

        let delegate = SequentialSectionEntryRow.EntryReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveEntry: { _, _ in moveCount += 1 }
        )

        delegate.applyLiveReorderIfNeeded()
        XCTAssertEqual(moveCount, 1)
        XCTAssertEqual(hoverTargetItemID, second.id)
    }

    func test_applyLiveReorder_secondCall_sameTargetSkipsExtraMove() {
        let first = Entry(fullText: "First")
        let second = Entry(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID?
        var moveCount = 0

        let delegate = SequentialSectionEntryRow.EntryReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveEntry: { _, _ in moveCount += 1 }
        )

        delegate.applyLiveReorderIfNeeded()
        delegate.applyLiveReorderIfNeeded()
        XCTAssertEqual(moveCount, 1)
    }

    func test_performDrop_withoutPriorLiveReorder_appliesMoveWhenNeeded() {
        let first = Entry(fullText: "First")
        let second = Entry(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID?
        var moveCount = 0

        let delegate = SequentialSectionEntryRow.EntryReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveEntry: { _, _ in moveCount += 1 }
        )

        XCTAssertTrue(delegate.performDrop())
        XCTAssertEqual(moveCount, 1)
        XCTAssertNil(draggingItemID)
    }

    func test_performDrop_afterLiveReflowWhenAlreadyPlaced_skipsMoveButClearsState() {
        let first = Entry(fullText: "First")
        let second = Entry(fullText: "Second")
        let items = [second, first]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID? = second.id
        var moveCount = 0

        let delegate = SequentialSectionEntryRow.EntryReorderDropDelegate(
            targetIndex: 0,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveEntry: { _, _ in moveCount += 1 }
        )

        XCTAssertTrue(delegate.performDrop())
        XCTAssertEqual(moveCount, 0)
        XCTAssertNil(draggingItemID)
        XCTAssertNil(hoverTargetItemID)
    }

    func test_performDrop_withoutInternalDrag_returnsFalse() {
        let item = Entry(fullText: "Only")
        var draggingItemID: UUID?
        var hoverTargetItemID: UUID?
        var didMove = false
        let delegate = SequentialSectionEntryRow.EntryReorderDropDelegate(
            targetIndex: 0,
            items: [item],
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveEntry: { _, _ in didMove = true }
        )

        let didHandleDrop = delegate.performDrop()

        XCTAssertFalse(didHandleDrop)
        XCTAssertFalse(didMove)
    }

    func test_entryReorderMoveParameters_nilWhenHoveringDraggedChip() {
        let first = Entry(fullText: "First")
        let second = Entry(fullText: "Second")
        let items = [first, second]
        XCTAssertNil(
            SequentialSectionEntryRow.EntryReorderDropDelegate.entryReorderMoveParameters(
                activeDragID: first.id,
                items: items,
                targetIndex: 0
            )
        )
    }

    func test_entryReorderMoveParameters_movesEarlierItemTowardLaterChip() {
        let first = Entry(fullText: "First")
        let second = Entry(fullText: "Second")
        let third = Entry(fullText: "Third")
        let items = [first, second, third]
        let params = SequentialSectionEntryRow.EntryReorderDropDelegate.entryReorderMoveParameters(
            activeDragID: first.id,
            items: items,
            targetIndex: 2
        )
        XCTAssertEqual(params?.source, 0)
        XCTAssertEqual(params?.destination, 3)
    }
}
