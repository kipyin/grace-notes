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

    /// Returns whether `handleAddEntryTap` applied. Callers that reveal the add morph should run
    /// `restoreInputFocus` **after** `isAddMorphComposerVisible` becomes true (next run loop).
    static func addNewTapped(context: SectionContext) -> Bool {
        JournalScreenEntryHandling.handleAddEntryTap(
            input: context.input,
            editingIndex: context.editingIndex,
            operations: context.operations,
            isTransitioning: context.isTransitioning
        )
    }

    static func entryTapped(
        context: SectionContext,
        tapIndex: Int,
        restoreInputFocus: (FocusState<Bool>.Binding) -> Void
    ) {
        // Row taps come from list indices; ignore out-of-range values so we do not run transitions
        // or keyboard focus restoration for a non-existent row (e.g. stale index after a data race).
        guard tapIndex >= 0, tapIndex < context.operations.count else { return }
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
