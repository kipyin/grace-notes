import SwiftUI

/// Parameters for chip tap/delete operations. Used to reduce duplication across gratitude/need/person sections.
struct ChipSectionOperations {
    let update: (Int, String) async -> Bool
    let add: (String) async -> Bool
    let fullText: (Int) -> String?
    let count: Int
}

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
        remove: (Int) -> Bool,
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
    static func performChipTap(
        tapIndex: Int,
        input: Binding<String>,
        editingIndex: Binding<Int?>,
        operations: ChipSectionOperations
    ) {
        Task { @MainActor in
            var canSwitch = true
            if let currentIndex = editingIndex.wrappedValue, !input.wrappedValue.isEmpty {
                let succeeded = await operations.update(currentIndex, input.wrappedValue)
                canSwitch = succeeded
                if succeeded { input.wrappedValue = "" }
            } else if !input.wrappedValue.isEmpty, operations.count < JournalViewModel.slotCount {
                let succeeded = await operations.add(input.wrappedValue)
                canSwitch = succeeded
                if succeeded { input.wrappedValue = "" }
            }
            if canSwitch, let full = operations.fullText(tapIndex) {
                input.wrappedValue = full
                editingIndex.wrappedValue = tapIndex
            }
        }
    }
}
