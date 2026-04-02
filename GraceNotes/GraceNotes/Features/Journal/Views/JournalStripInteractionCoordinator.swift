import SwiftUI

/// Orchestrates strip add / tap flows and keyboard focus restoration for Today’s sequential sections.
@MainActor
enum JournalStripInteractionCoordinator {
    struct SectionContext {
        let input: Binding<String>
        let editingIndex: Binding<Int?>
        let isTransitioning: Binding<Bool>
        let inputFocus: FocusState<Bool>.Binding
        let operations: StripSectionOperations
    }

    static func addNewTapped(
        context: SectionContext,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        let handled = JournalScreenStripHandling.handleAddStripTap(
            input: context.input,
            editingIndex: context.editingIndex,
            operations: context.operations,
            isTransitioning: context.isTransitioning
        )
        if handled {
            restoreInputFocus(context.inputFocus)
        }
    }

    static func stripTapped(
        context: SectionContext,
        tapIndex: Int,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        let handled = JournalScreenStripHandling.performStripTap(
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
