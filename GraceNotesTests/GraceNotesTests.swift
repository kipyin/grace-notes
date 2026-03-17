import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import GraceNotes

@MainActor
final class JournalScreenChipHandlingTests: XCTestCase {
    func test_performChipTap_whenEditingUnchangedText_switchesWithoutCommitting() {
        var input = "Current full text"
        var editingIndex: Int? = 0
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

        JournalScreenChipHandling.performChipTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations
        )

        XCTAssertFalse(didUpdate)
        XCTAssertFalse(didAdd)
        XCTAssertFalse(didSummarize)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Tapped full text")
    }

    func test_performChipTap_whenEditingChangedText_commitsAndSchedulesSummary() {
        var input = "Edited text"
        var editingIndex: Int? = 0
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

        JournalScreenChipHandling.performChipTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations
        )

        XCTAssertEqual(summarizedIndex, 0)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Target full text")
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

    func test_submitChipSection_whenAddSucceeds_clearsInput() async {
        var input = "New text"
        var editingIndex: Int?

        await JournalScreenChipHandling.submitChipSection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            update: { _, _ in true },
            add: { _ in true }
        )

        XCTAssertNil(editingIndex)
        XCTAssertEqual(input, "")
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
    private struct MockDropInfo: DropInfo {
        var location: CGPoint = .zero

        func hasItemsConforming(to contentTypes: [UTType]) -> Bool {
            true
        }

        func itemProviders(for contentTypes: [UTType]) -> [NSItemProvider] {
            []
        }
    }

    func test_dropEntered_doesNotApplyMoveUntilDropCompletes() {
        let first = JournalItem(fullText: "First")
        let second = JournalItem(fullText: "Second")
        let items = [first, second]
        var draggingItemID: UUID? = first.id
        var didMove = false

        let delegate = ChipReorderDropDelegate(
            targetIndex: 1,
            items: items,
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            onMoveChip: { _, _ in didMove = true }
        )

        delegate.dropEntered(info: MockDropInfo())
        XCTAssertFalse(didMove)

        let didHandleDrop = delegate.performDrop(info: MockDropInfo())
        XCTAssertTrue(didHandleDrop)
        XCTAssertTrue(didMove)
    }

    func test_performDrop_withoutInternalDrag_returnsFalse() {
        let item = JournalItem(fullText: "Only")
        var draggingItemID: UUID?
        var didMove = false
        let delegate = ChipReorderDropDelegate(
            targetIndex: 0,
            items: [item],
            draggingItemID: Binding(get: { draggingItemID }, set: { draggingItemID = $0 }),
            onMoveChip: { _, _ in didMove = true }
        )

        let didHandleDrop = delegate.performDrop(info: MockDropInfo())

        XCTAssertFalse(didHandleDrop)
        XCTAssertFalse(didMove)
    }
}
