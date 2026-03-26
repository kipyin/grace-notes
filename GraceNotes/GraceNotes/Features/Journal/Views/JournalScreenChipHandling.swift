import SwiftUI

/// Parameters for chip tap operations. Used to reduce duplication across gratitude/need/person sections.
/// Uses immediate update/add (no await) with background summarization for instant chip switching.
@MainActor
struct ChipSectionOperations {
    let updateImmediate: (Int, String) -> Int?
    let addImmediate: (String) -> Int?
    let remove: (Int) -> Bool
    let fullText: (Int) -> String?
    let count: Int
    let summarizeAndUpdateChip: (Int) -> Void
}

@MainActor
enum JournalScreenChipHandling {

    /// Submits the current input as an immediate update/add and clears the draft on success.
    /// Returns true when a state transition was applied.
    static func submitChipSection(
        editingIndex: Binding<Int?>,
        input: Binding<String>,
        operations: ChipSectionOperations,
        isTransitioning: Binding<Bool>
    ) -> Bool {
        let trimmed = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = editingIndex.wrappedValue, trimmed.isEmpty {
            guard beginTransition(isTransitioning) else { return false }
            defer { endTransition(isTransitioning) }

            guard operations.remove(index) else { return false }
            editingIndex.wrappedValue = nil
            input.wrappedValue = ""
            return true
        }

        guard !trimmed.isEmpty else { return false }

        guard beginTransition(isTransitioning) else { return false }
        defer { endTransition(isTransitioning) }

        if let index = editingIndex.wrappedValue {
            guard let updatedIndex = operations.updateImmediate(index, input.wrappedValue) else { return false }
            operations.summarizeAndUpdateChip(updatedIndex)
            editingIndex.wrappedValue = nil
            input.wrappedValue = ""
            return true
        } else {
            guard let newIndex = operations.addImmediate(input.wrappedValue) else { return false }
            operations.summarizeAndUpdateChip(newIndex)
            input.wrappedValue = ""
            return true
        }
    }

    /// Handles `(+)` tap without dropping an active draft.
    /// Returns true when the interaction was accepted.
    static func handleAddChipTap(
        input: Binding<String>,
        editingIndex: Binding<Int?>,
        operations: ChipSectionOperations,
        isTransitioning: Binding<Bool>
    ) -> Bool {
        guard beginTransition(isTransitioning) else { return false }
        defer { endTransition(isTransitioning) }

        let trimmed = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let currentIndex = editingIndex.wrappedValue, trimmed.isEmpty {
            guard operations.remove(currentIndex) else { return false }
            input.wrappedValue = ""
            editingIndex.wrappedValue = nil
            return true
        }

        if let currentIndex = editingIndex.wrappedValue, !trimmed.isEmpty {
            guard let updatedIndex = operations.updateImmediate(currentIndex, input.wrappedValue) else { return false }
            operations.summarizeAndUpdateChip(updatedIndex)
        } else if !trimmed.isEmpty {
            guard let newIndex = operations.addImmediate(input.wrappedValue) else { return false }
            operations.summarizeAndUpdateChip(newIndex)
        }

        input.wrappedValue = ""
        editingIndex.wrappedValue = nil
        return true
    }

    /// Performs the delete-chip flow: removes the item and updates editing state.
    static func performDelete(
        index: Int,
        remove: @MainActor (Int) -> Bool,
        input: Binding<String>,
        editingIndex: Binding<Int?>
    ) {
        _ = remove(index)
        if editingIndex.wrappedValue == index {
            editingIndex.wrappedValue = nil
            input.wrappedValue = ""
        } else if let editing = editingIndex.wrappedValue, editing > index {
            editingIndex.wrappedValue = editing - 1
        }
    }

    /// Reorders a chip and remaps editing index to keep editing state on the same item.
    static func performMove(
        from sourceIndex: Int,
        to destinationOffset: Int,
        move: @MainActor (Int, Int) -> Bool,
        editingIndex: Binding<Int?>
    ) {
        guard move(sourceIndex, destinationOffset) else { return }
        guard let currentEditing = editingIndex.wrappedValue else { return }

        if let remapped = remappedEditingIndex(
            currentEditing,
            sourceIndex: sourceIndex,
            destinationOffset: destinationOffset
        ) {
            editingIndex.wrappedValue = remapped
        }
    }

    /// Performs the chip-tap-to-edit flow: commits any pending input, then loads the tapped chip into the editor.
    /// Switch is immediate; summarization runs in background when input changed.
    /// Returns true when the interaction was accepted.
    static func performChipTap(
        tapIndex: Int,
        input: Binding<String>,
        editingIndex: Binding<Int?>,
        operations: ChipSectionOperations,
        isTransitioning: Binding<Bool>
    ) -> Bool {
        guard beginTransition(isTransitioning) else { return false }
        defer { endTransition(isTransitioning) }

        let trimmed = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let currentIndex = editingIndex.wrappedValue, trimmed.isEmpty {
            guard operations.remove(currentIndex) else { return false }
            applyChipTapAfterRemovingEmptyEdit(
                tapIndex: tapIndex,
                removedIndex: currentIndex,
                input: input,
                editingIndex: editingIndex,
                operations: operations
            )
            return true
        }

        if switchChipTapWhenTextUnchangedFromStored(
            trimmed: trimmed,
            tapIndex: tapIndex,
            input: input,
            editingIndex: editingIndex,
            operations: operations
        ) {
            return true
        }

        var canSwitch = true
        if let currentIndex = editingIndex.wrappedValue, !trimmed.isEmpty {
            if let updatedIndex = operations.updateImmediate(currentIndex, input.wrappedValue) {
                input.wrappedValue = ""
                operations.summarizeAndUpdateChip(updatedIndex)
            } else {
                canSwitch = false
            }
        } else if !trimmed.isEmpty, operations.count < JournalViewModel.slotCount {
            if let newIndex = operations.addImmediate(input.wrappedValue) {
                input.wrappedValue = ""
                operations.summarizeAndUpdateChip(newIndex)
            } else {
                canSwitch = false
            }
        }

        if canSwitch, let full = operations.fullText(tapIndex) {
            input.wrappedValue = full
            editingIndex.wrappedValue = tapIndex
        }
        return true
    }

    /// After deleting the edited row because input was whitespace-only, either exit editing or open
    /// another strip (indices shift when the removed row was above the tap).
    private static func applyChipTapAfterRemovingEmptyEdit(
        tapIndex: Int,
        removedIndex: Int,
        input: Binding<String>,
        editingIndex: Binding<Int?>,
        operations: ChipSectionOperations
    ) {
        input.wrappedValue = ""
        if tapIndex == removedIndex {
            editingIndex.wrappedValue = nil
            return
        }
        let effectiveTapIndex = tapIndex > removedIndex ? tapIndex - 1 : tapIndex
        if let full = operations.fullText(effectiveTapIndex) {
            input.wrappedValue = full
            editingIndex.wrappedValue = effectiveTapIndex
        } else {
            editingIndex.wrappedValue = nil
        }
    }

    /// When the draft matches the stored full text, switch to the tapped strip without persisting again.
    private static func switchChipTapWhenTextUnchangedFromStored(
        trimmed: String,
        tapIndex: Int,
        input: Binding<String>,
        editingIndex: Binding<Int?>,
        operations: ChipSectionOperations
    ) -> Bool {
        guard let currentIndex = editingIndex.wrappedValue, !trimmed.isEmpty else { return false }
        let stored = operations.fullText(currentIndex) ?? ""
        guard trimmed == stored else { return false }
        if let full = operations.fullText(tapIndex) {
            input.wrappedValue = full
            editingIndex.wrappedValue = tapIndex
        }
        return true
    }

    private static func remappedEditingIndex(
        _ editingIndex: Int,
        sourceIndex: Int,
        destinationOffset: Int
    ) -> Int? {
        let destinationIndex = destinationOffset > sourceIndex ? destinationOffset - 1 : destinationOffset

        if editingIndex == sourceIndex {
            return destinationIndex
        }

        if sourceIndex < destinationIndex, editingIndex > sourceIndex, editingIndex <= destinationIndex {
            return editingIndex - 1
        }

        if destinationIndex < sourceIndex, editingIndex >= destinationIndex, editingIndex < sourceIndex {
            return editingIndex + 1
        }

        return editingIndex
    }

    private static func beginTransition(_ isTransitioning: Binding<Bool>) -> Bool {
        if isTransitioning.wrappedValue {
            return false
        }
        isTransitioning.wrappedValue = true
        return true
    }

    private static func endTransition(_ isTransitioning: Binding<Bool>) {
        isTransitioning.wrappedValue = false
    }
}
