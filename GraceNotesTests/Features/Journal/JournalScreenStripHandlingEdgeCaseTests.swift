import SwiftUI
import XCTest
@testable import GraceNotes

@MainActor
final class JournalScreenStripHandlingEdgeCaseTests: XCTestCase {
    func test_performStripTap_whenUpdateFails_doesNotSwitchToTappedStrip() {
        var input = "Edited draft"
        var editingIndex: Int? = 0
        var isTransitioning = false
        let operations = StripSectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { _ in 99 },
            remove: { _ in false },
            fullText: { index in
                index == 0 ? "Stored" : "Other line"
            },
            count: 2
        )

        let handled = JournalScreenStripHandling.performStripTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(input, "Edited draft")
        XCTAssertEqual(editingIndex, 0)
    }

    func test_submitStripSection_whenEditingWhitespaceOnly_deletesAndClearsDraft() {
        var input = "   \n"
        var editingIndex: Int? = 1
        var isTransitioning = false
        var didUpdate = false
        var didRemove = false
        let operations = StripSectionOperations(
            updateImmediate: { _, _ in
                didUpdate = true
                return 0
            },
            addImmediate: { _ in 0 },
            remove: { index in
                didRemove = true
                return index == 1
            },
            fullText: { _ in nil },
            count: 0
        )

        let didSubmit = JournalScreenStripHandling.submitStripSection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(didSubmit)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
        XCTAssertFalse(didUpdate)
        XCTAssertTrue(didRemove)
        XCTAssertFalse(isTransitioning)
    }

    func test_submitStripSection_whenAddingWhitespaceOnly_returnsFalseWithoutMutating() {
        var input = "   \n"
        var editingIndex: Int?
        var isTransitioning = false
        var didUpdate = false
        var didAdd = false
        var didRemove = false
        let operations = StripSectionOperations(
            updateImmediate: { _, _ in
                didUpdate = true
                return 0
            },
            addImmediate: { _ in
                didAdd = true
                return 0
            },
            remove: { _ in
                didRemove = true
                return true
            },
            fullText: { _ in nil },
            count: 0
        )

        let didSubmit = JournalScreenStripHandling.submitStripSection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(input, "   \n")
        XCTAssertNil(editingIndex)
        XCTAssertFalse(didUpdate)
        XCTAssertFalse(didAdd)
        XCTAssertFalse(didRemove)
        XCTAssertFalse(isTransitioning)
    }

    func test_submitStripSection_whenEditingAndUpdateSucceeds_clearsDraft() {
        var input = "Revision"
        var editingIndex: Int? = 2
        var isTransitioning = false
        let operations = StripSectionOperations(
            updateImmediate: { index, _ in index },
            addImmediate: { _ in nil },
            remove: { _ in false },
            fullText: { _ in nil },
            count: 3
        )

        let didSubmit = JournalScreenStripHandling.submitStripSection(
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            input: Binding(get: { input }, set: { input = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(didSubmit)
        XCTAssertEqual(input, "")
        XCTAssertNil(editingIndex)
    }

    func test_performDelete_whenDeletingEditedStrip_clearsDraft() {
        var input = "Draft"
        var editingIndex: Int? = 2

        JournalScreenStripHandling.performDelete(
            index: 2,
            remove: { _ in true },
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertNil(editingIndex)
        XCTAssertEqual(input, "")
    }

    func test_performMove_whenMoveFails_leavesEditingIndex() {
        var editingIndex: Int? = 2
        var didCallMove = false

        JournalScreenStripHandling.performMove(
            from: 0,
            to: 1,
            move: { _, _ in
                didCallMove = true
                return false
            },
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertTrue(didCallMove)
        XCTAssertEqual(editingIndex, 2)
    }

    func test_performMove_whenNotEditing_leavesNilEditingIndex() {
        var editingIndex: Int?
        var didCallMove = false

        JournalScreenStripHandling.performMove(
            from: 0,
            to: 1,
            move: { _, _ in
                didCallMove = true
                return true
            },
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 })
        )

        XCTAssertTrue(didCallMove)
        XCTAssertNil(editingIndex)
    }

    func test_handleAddStripTap_whileTransitioning_returnsFalseWithoutMutating() {
        var input = "Draft"
        var editingIndex: Int?
        var isTransitioning = true
        var didAdd = false
        let operations = StripSectionOperations(
            updateImmediate: { _, _ in 0 },
            addImmediate: { _ in
                didAdd = true
                return 0
            },
            remove: { _ in false },
            fullText: { _ in nil },
            count: 0
        )

        let handled = JournalScreenStripHandling.handleAddStripTap(
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertFalse(handled)
        XCTAssertEqual(input, "Draft")
        XCTAssertNil(editingIndex)
        XCTAssertFalse(didAdd)
    }

    func test_performStripTap_whenNotEditingButDraftPresent_addsThenOpensTappedStrip() {
        var input = "New draft line"
        var editingIndex: Int?
        var isTransitioning = false
        var addedIndex: Int?
        let operations = StripSectionOperations(
            updateImmediate: { _, _ in nil },
            addImmediate: { text in
                addedIndex = 0
                XCTAssertEqual(text, "New draft line")
                return 0
            },
            remove: { _ in false },
            fullText: { index in
                index == 1 ? "Second saved" : "First saved"
            },
            count: 2
        )

        let handled = JournalScreenStripHandling.performStripTap(
            tapIndex: 1,
            input: Binding(get: { input }, set: { input = $0 }),
            editingIndex: Binding(get: { editingIndex }, set: { editingIndex = $0 }),
            operations: operations,
            isTransitioning: Binding(get: { isTransitioning }, set: { isTransitioning = $0 })
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(editingIndex, 1)
        XCTAssertEqual(input, "Second saved")
        XCTAssertEqual(addedIndex, 0)
    }
}
