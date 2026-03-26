import SwiftUI

/// Orchestrates chip strip add / tap flows and keyboard focus restoration for Today’s sequential sections.
/// Mutations stay in `JournalScreenChipHandling`; this type is the single call site for “handle + maybe refocus”.
@MainActor
enum JournalChipInteractionCoordinator {
    struct SectionContext {
        let input: Binding<String>
        let editingIndex: Binding<Int?>
        let isTransitioning: Binding<Bool>
        let inputFocus: FocusState<Bool>.Binding
        let operations: ChipSectionOperations
    }

    static func addNewTapped(
        context: SectionContext,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        let handled = JournalScreenChipHandling.handleAddChipTap(
            input: context.input,
            editingIndex: context.editingIndex,
            operations: context.operations,
            isTransitioning: context.isTransitioning
        )
        if handled {
            restoreInputFocus(context.inputFocus)
        }
    }

    static func chipTapped(
        context: SectionContext,
        tapIndex: Int,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        let handled = JournalScreenChipHandling.performChipTap(
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
