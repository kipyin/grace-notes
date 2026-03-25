import SwiftUI
import XCTest
@testable import GraceNotes

@MainActor
final class JournalScreenChipHandlingTests: XCTestCase {
    func test_performChipTap_whenEditingUnchangedText_switchesWithoutCommitting() {
        var input = "Current full text"
        var editingIndex: Int? = 0
        var isTransitioning = false
        var didUpdate = false
        var didAdd = false
        var didSummarize = false

        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in
                didUpdate = true
                return 0
            },
            addImmediate: { _ in
                didAdd = true
                return 1
            },
            fullText: { index in
                index == 0 ? "Current full text" : "Tapped full text"
            },
            count: 2,
            summarizeAndUpdateChip: { _ in
                didSummarize = true
            }
        )

        let handled = JournalScreenChipHandling.performChipTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertFalse(didUpdate)
        XCTAssertFalse(didAdd)
        XCTAssertFalse(didSummarize)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Tapped full text")
    }

    func test_performChipTap_whenEditingChangedText_commitsAndSchedulesSummary() {
        var input = "Edited text"
        var editingIndex: Int? = 0
        var isTransitioning = false
        var summarizedIndex: Int?

        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in 0 },
            addImmediate: { _ in nil },
            fullText: { index in
                index == 0 ? "Original" : "Target full text"
            },
            count: 2,
            summarizeAndUpdateChip: { index in
                summarizedIndex = index
            }
        )

        let handled = JournalScreenChipHandling.performChipTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(summarizedIndex, 0)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Target full text")
    }

    func test_performChipTap_whenTransitionInFlight_ignoresTap() {
        var input = "Draft text"
        var editingIndex: Int? = 0
        var isTransitioning = true
        var didSummarize = false

        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in 0 },
            addImmediate: { _ in 1 },
            fullText: { _ in "Target full text" },
            count: 1,
            summarizeAndUpdateChip: { _ in
                didSummarize = true
            }
        )

        let handled = JournalScreenChipHandling.performChipTap(
            tapIndex: 0,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertFalse(handled)
        XCTAssertEqual(input, "Draft text")
        XCTAssertEqual(editingIndex, 0)
        XCTAssertFalse(didSummarize)
    }

    func test_performDelete_whenDeletingEarlierItem_shiftsEditingIndex() {
        var input = "In progress"
        var editingIndex: Int? = 3

        JournalScreenChipHandling.performDelete(
            index: 1,
            remove: { _ in true },
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertEqual(editingIndex, 2)
        XCTAssertEqual(input, "In progress")
    }

    func test_submitChipSection_whenAddSucceeds_clearsInput() {
        var input = "New text"
        var editingIndex: Int?
        var isTransitioning = false
        var summarizedIndex: Int?
        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in 2 },
            fullText: { _ in nil },
            count: 2,
            summarizeAndUpdateChip: { summarizedIndex = $0 }
        )

        let didSubmit = JournalScreenChipHandling.submitChipSection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(didSubmit)
        XCTAssertNil(editingIndex)
        XCTAssertEqual(input, "")
        XCTAssertEqual(summarizedIndex, 2)
    }

    func test_submitChipSection_whenTransitionInFlight_ignoresDuplicateSubmit() {
        var input = "New text"
        var editingIndex: Int?
        var isTransitioning = true
        var didAdd = false
        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in
                didAdd = true
                return 0
            },
            fullText: { _ in nil },
            count: 0,
            summarizeAndUpdateChip: { _ in }
        )

        let didSubmit = JournalScreenChipHandling.submitChipSection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertFalse(didSubmit)
        XCTAssertFalse(didAdd)
        XCTAssertEqual(input, "New text")
    }

    func test_handleAddChipTap_withActiveDraft_commitsAndStartsFreshInput() {
        var input = "Keep this draft"
        var editingIndex: Int? = 1
        var isTransitioning = false
        var summarizedIndex: Int?
        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in 1 },
            addImmediate: { _ in nil },
            fullText: { _ in nil },
            count: 2,
            summarizeAndUpdateChip: { summarizedIndex = $0 }
        )

        let handled = JournalScreenChipHandling.handleAddChipTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
        XCTAssertEqual(summarizedIndex, 1)
    }

    func test_handleAddChipTap_withEmptyDraft_exitsEditingMode() {
        var input = "   "
        var editingIndex: Int? = 2
        var isTransitioning = false
        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in nil },
            fullText: { _ in nil },
            count: 2,
            summarizeAndUpdateChip: { _ in }
        )

        let handled = JournalScreenChipHandling.handleAddChipTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
    }

    func test_handleAddChipTap_whenNotEditingWithDraft_addsDraftAndStartsFreshInput() {
        var input = "New draft"
        var editingIndex: Int?
        var isTransitioning = false
        var summarizedIndex: Int?
        let operations = ChipSectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in 2 },
            fullText: { _ in nil },
            count: 2,
            summarizeAndUpdateChip: { summarizedIndex = $0 }
        )

        let handled = JournalScreenChipHandling.handleAddChipTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
        XCTAssertEqual(summarizedIndex, 2)
    }

    func test_performMove_whenEditingMovedItem_updatesEditingIndexToDestination() {
        var editingIndex: Int? = 0

        JournalScreenChipHandling.performMove(
            from: 0,
            to: 3,
            move: { _, _ in true },
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertEqual(editingIndex, 2)
    }

    func test_performMove_whenEditingItemBetweenRange_shiftsEditingIndex() {
        var editingIndex: Int? = 2

        JournalScreenChipHandling.performMove(
            from: 0,
            to: 3,
            move: { _, _ in true },
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertEqual(editingIndex, 1)
    }
}

@MainActor
final class ChipReorderDropDelegateTests: XCTestCase {
    func test_applyLiveReorder_movesWhenDraggingOverDifferentChip() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID?
        var moveCount = 0

        let delegate = SequentialSectionChipRow.ChipReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveChip: { _, _ in moveCount += 1 }
        )

        delegate.applyLiveReorderIfNeeded()
        XCTAssertEqual(moveCount, 1)
        XCTAssertEqual(hoverTargetItemID, second.id)
    }

    func test_applyLiveReorder_secondCall_sameTargetSkipsExtraMove() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID?
        var moveCount = 0

        let delegate = SequentialSectionChipRow.ChipReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveChip: { _, _ in moveCount += 1 }
        )

        delegate.applyLiveReorderIfNeeded()
        delegate.applyLiveReorderIfNeeded()
        XCTAssertEqual(moveCount, 1)
    }

    func test_performDrop_withoutPriorLiveReorder_appliesMoveWhenNeeded() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID?
        var moveCount = 0

        let delegate = SequentialSectionChipRow.ChipReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveChip: { _, _ in moveCount += 1 }
        )

        XCTAssertTrue(delegate.performDrop())
        XCTAssertEqual(moveCount, 1)
        XCTAssertNil(draggingItemID)
    }

    func test_performDrop_afterLiveReflowWhenAlreadyPlaced_skipsMoveButClearsState() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let items = [second, first]
        var draggingItemID: UUID? = first.id
        var hoverTargetItemID: UUID? = second.id
        var moveCount = 0

        let delegate = SequentialSectionChipRow.ChipReorderDropDelegate(
            targetIndex: 0,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveChip: { _, _ in moveCount += 1 }
        )

        XCTAssertTrue(delegate.performDrop())
        XCTAssertEqual(moveCount, 0)
        XCTAssertNil(draggingItemID)
        XCTAssertNil(hoverTargetItemID)
    }

    func test_performDrop_withoutInternalDrag_returnsFalse() {
        let item = JournalItem(fullText: "Only")
        var draggingItemID: UUID?
        var hoverTargetItemID: UUID?
        var didMove = false
        let delegate = SequentialSectionChipRow.ChipReorderDropDelegate(
            targetIndex: 0,
            items: [item],
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            hoverTargetItemID: Binding(get: { hoverTargetItemID }, set: { hoverTargetItemID = $0 }),
            reduceMotion: true,
            onMoveChip: { _, _ in didMove = true }
        )

        let didHandleDrop = delegate.performDrop()

        XCTAssertFalse(didHandleDrop)
        XCTAssertFalse(didMove)
    }

    func test_chipReorderMoveParameters_nilWhenHoveringDraggedChip() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let items = [first, second]
        XCTAssertNil(
            SequentialSectionChipRow.ChipReorderDropDelegate.chipReorderMoveParameters(
                activeDragID: first.id,
                items: items,
                targetIndex: 0
            )
        )
    }

    func test_chipReorderMoveParameters_movesEarlierItemTowardLaterChip() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let third = JournalItem(fullText: "Third")
        let items = [first, second, third]
        let params = SequentialSectionChipRow.ChipReorderDropDelegate.chipReorderMoveParameters(
            activeDragID: first.id,
            items: items,
            targetIndex: 2
        )
        XCTAssertEqual(params?.source, 0)
        XCTAssertEqual(params?.destination, 3)
    }
}
