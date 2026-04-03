import SwiftUI

/// Orchestrates sequential entry add / tap flows and keyboard focus restoration for Today’s sections.
@MainActor
enum JournalEntryInteractionCoordinator {
    struct SectionContext {
        let input: Binding<String>
        let editingIndex: Binding<Int?>
        let isTransitioning: Binding<Bool>
        let inputFocus: FocusState<Bool>.Binding
        let operations: EntrySectionOperations
    }

    static func addNewTapped(
        context: SectionContext,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        let handled = JournalScreenEntryHandling.handleAddEntryTap(
            input: context.input,
            editingIndex: context.editingIndex,
            operations: context.operations,
            isTransitioning: context.isTransitioning
        )
        if handled {
            restoreInputFocus(context.inputFocus)
        }
    }

    static func entryTapped(
        context: SectionContext,
        tapIndex: Int,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        let handled = JournalScreenEntryHandling.performEntryTap(
            tapIndex: tapIndex,
            input: context.input,
            editingIndex: context.editingIndex,
            operations: context.operations,
            isTransitioning: context.isTransitioning
        )
        if handled {
            restoreInputFocus(context.inputFocus)
        }
    }
}
