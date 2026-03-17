import SwiftUI

/// Parameters for chip tap operations. Used to reduce duplication across gratitude/need/person sections.
/// Uses immediate update/add (no await) with background summarization for instant chip switching.
@MainActor
struct ChipSectionOperations {
    let updateImmediate: (Int, String) -> Int?
    let addImmediate: (String) -> Int?
    let fullText: (Int) -> String?
    let count: Int
    let summarizeAndUpdateChip: (Int) -> Void
}

@MainActor
enum JournalScreenChipHandling {

    /// Submits the current input as update or add, then clears input on success.
    static func submitChipSection(
        editingIndex: Binding<Int?>,
        input: Binding<String>,
        update: (Int, String) async -> Bool,
        add: (String) async -> Bool
    ) async {
        let succeeded: Bool
        if let index = editingIndex.wrappedValue {
            succeeded = await update(index, input.wrappedValue)
            if succeeded { editingIndex.wrappedValue = nil }
        } else {
            succeeded = await add(input.wrappedValue)
        }
        if succeeded { input.wrappedValue = "" }
    }

    /// Clears the chip input field and editing state.
    static func clearChipInput(input: Binding<String>, editingIndex: Binding<Int?>) {
        editingIndex.wrappedValue = nil
        input.wrappedValue = ""
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

    /// Performs the chip-tap-to-edit flow: commits any pending input, then loads the tapped chip into the editor.
    /// Switch is immediate; summarization runs in background when input changed.
    static func performChipTap(
        tapIndex: Int,
        input: Binding<String>,
        editingIndex: Binding<Int?>,
        operations: ChipSectionOperations
    ) {
        let trimmed = input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let currentIndex = editingIndex.wrappedValue, !trimmed.isEmpty {
            let stored = operations.fullText(currentIndex) ?? ""
            if trimmed == stored {
                if let full = operations.fullText(tapIndex) {
                    input.wrappedValue = full
                    editingIndex.wrappedValue = tapIndex
                }
                return
            }
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
    }
}
