import SwiftUI

struct SequentialSectionView: View {
    /// Progress-dot slot state for the section header.
    enum SlotStatus {
        case edited
        case editing
        case pending
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.todayJournalPalette) private var palette

    let title: String
    let addButtonTitle: String
    let addButtonAccessibilityHint: String
    let showsTrailingChevronOnAddRow: Bool
    /// Guided onboarding title shown above the section header (optional; omitted when empty).
    let guidanceTitle: String?
    /// Guided onboarding message shown under `guidanceTitle`.
    let guidanceMessage: String?
    /// Optional second line under `guidanceMessage` (e.g. keyboard hint).
    let guidanceMessageSecondary: String?
    let items: [Entry]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    /// When set (e.g. UI tests), entry rows use identifiers `"\(prefix).\(index)"` for stable XCUITest queries.
    let entryAccessibilityIdentifierPrefix: String?
    /// When set (e.g. UI tests), the section (+) control exposes this `accessibilityIdentifier`.
    let addItemAccessibilityIdentifier: String?
    let onboardingState: JournalOnboardingSectionState
    let isTransitioning: Bool
    @Binding var inputText: String
    let editingIndex: Int?
    let inputFocus: FocusState<Bool>.Binding?
    /// Fires when the section input field loses focus; handler ignores empty drafts.
    let onInputFocusLost: (() -> Void)?
    let onSubmit: () -> Void
    let onItemTap: (Int) -> Void
    let onMoveItem: ((Int, Int) -> Void)?
    let onDeleteItem: ((Int) -> Void)?
    let onAddNew: (() -> Bool)?
    /// After a successful add tap, run once the add morph is visible (e.g. keyboard focus on the composer).
    let onAfterAddMorphRevealed: (() -> Void)?
    /// When true, another entry row or add morph in this journal is focused; fades non-focused rows.
    let ambientInlineEditingActive: Bool
    /// This section contains the focused inline editor or add morph composer.
    let sectionHostsInlineFocus: Bool
    /// Commits inline editing when the user taps outside the active field (e.g. dimmed section overlay).
    let onRequestDismissInlineEditing: (() -> Void)?
    /// Optional `ScrollViewReader` id on the chip list + composer (excludes header).
    /// Used for Needs/People keyboard avoidance.
    let keyboardScrollAnchorID: JournalScrollTarget?
    @Binding var isAddMorphComposerVisible: Bool
    @State private var draggingItemID: UUID?
    /// Item UUID that last triggered a live reorder during this drag.
    /// Skips redundant `dropUpdated` work when indices shift but the finger stays on the same item.
    @State private var itemReorderHoverTargetItemID: UUID?
    @State private var isEditingPulseExpanded = false

    init(
        title: String,
        addButtonTitle: String,
        addButtonAccessibilityHint: String,
        showsTrailingChevronOnAddRow: Bool = false,
        guidanceTitle: String? = nil,
        guidanceMessage: String? = nil,
        guidanceMessageSecondary: String? = nil,
        items: [Entry],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        entryAccessibilityIdentifierPrefix: String? = nil,
        addItemAccessibilityIdentifier: String? = nil,
        onboardingState: JournalOnboardingSectionState = .standard,
        isTransitioning: Bool = false,
        inputText: Binding<String>,
        editingIndex: Int?,
        inputFocus: FocusState<Bool>.Binding? = nil,
        onInputFocusLost: (() -> Void)? = nil,
        onSubmit: @escaping () -> Void,
        onItemTap: @escaping (Int) -> Void,
        onMoveItem: ((Int, Int) -> Void)? = nil,
        onDeleteItem: ((Int) -> Void)? = nil,
        onAddNew: (() -> Bool)? = nil,
        onAfterAddMorphRevealed: (() -> Void)? = nil,
        isAddMorphComposerVisible: Binding<Bool> = .constant(false),
        ambientInlineEditingActive: Bool = false,
        sectionHostsInlineFocus: Bool = false,
        onRequestDismissInlineEditing: (() -> Void)? = nil,
        keyboardScrollAnchorID: JournalScrollTarget? = nil
    ) {
        self.title = title
        self.addButtonTitle = addButtonTitle
        self.addButtonAccessibilityHint = addButtonAccessibilityHint
        self.showsTrailingChevronOnAddRow = showsTrailingChevronOnAddRow
        self.guidanceTitle = guidanceTitle
        self.guidanceMessage = guidanceMessage
        self.guidanceMessageSecondary = guidanceMessageSecondary
        self.items = items
        self.placeholder = placeholder
        self.slotCount = slotCount
        self.inputAccessibilityIdentifier = inputAccessibilityIdentifier
        self.entryAccessibilityIdentifierPrefix = entryAccessibilityIdentifierPrefix
        self.addItemAccessibilityIdentifier = addItemAccessibilityIdentifier
        self.onboardingState = onboardingState
        self.isTransitioning = isTransitioning
        self._inputText = inputText
        self.editingIndex = editingIndex
        self.inputFocus = inputFocus
        self.onInputFocusLost = onInputFocusLost
        self.onSubmit = onSubmit
        self.onItemTap = onItemTap
        self.onMoveItem = onMoveItem
        self.onDeleteItem = onDeleteItem
        self.onAddNew = onAddNew
        self.onAfterAddMorphRevealed = onAfterAddMorphRevealed
        self._isAddMorphComposerVisible = isAddMorphComposerVisible
        self.ambientInlineEditingActive = ambientInlineEditingActive
        self.sectionHostsInlineFocus = sectionHostsInlineFocus
        self.onRequestDismissInlineEditing = onRequestDismissInlineEditing
        self.keyboardScrollAnchorID = keyboardScrollAnchorID
    }

    private var isInputFocused: Bool {
        inputFocus?.wrappedValue ?? false
    }

    /// Matches `SequentialSectionPrimaryColumn.activeEditingIndex`: ignore stale or out-of-bounds indices.
    private var activeEditingIndex: Int? {
        guard let editingIndex, items.indices.contains(editingIndex) else { return nil }
        return editingIndex
    }

    private var shouldAnimateEditingPulse: Bool {
        isInputFocused && !reduceMotion
    }

    private var slotStatuses: [SlotStatus] {
        (0..<slotCount).map { index in
            if activeEditingIndex == index {
                return .editing
            }
            if index < items.count {
                return .edited
            }
            if index == items.count, isAddMorphComposerVisible {
                return .editing
            }
            return .pending
        }
    }

    private var progressAccessibilityLabel: String {
        let editedCount = slotStatuses.filter { $0 == .edited }.count
        let editingCount = slotStatuses.filter { $0 == .editing }.count
        let pendingCount = slotStatuses.filter { $0 == .pending }.count
        return String(
            format: String(localized: "journal.section.progressSummary"),
            locale: Locale.current,
            title,
            editedCount,
            editingCount,
            pendingCount
        )
    }

    var body: some View {
        SequentialSectionPrimaryColumn(
            reduceMotion: reduceMotion,
            title: title,
            addButtonTitle: addButtonTitle,
            addButtonAccessibilityHint: addButtonAccessibilityHint,
            showsTrailingChevronOnAddRow: showsTrailingChevronOnAddRow,
            guidanceTitle: guidanceTitle,
            guidanceMessage: guidanceMessage,
            guidanceMessageSecondary: guidanceMessageSecondary,
            items: items,
            placeholder: placeholder,
            slotCount: slotCount,
            inputAccessibilityIdentifier: inputAccessibilityIdentifier,
            entryAccessibilityIdentifierPrefix: entryAccessibilityIdentifierPrefix,
            addItemAccessibilityIdentifier: addItemAccessibilityIdentifier,
            onboardingState: onboardingState,
            isTransitioning: isTransitioning,
            editingIndex: editingIndex,
            inputFocus: inputFocus,
            onInputFocusLost: onInputFocusLost,
            onSubmit: onSubmit,
            onItemTap: onItemTap,
            onMoveItem: onMoveItem,
            onDeleteItem: onDeleteItem,
            onAddNew: onAddNew,
            onAfterAddMorphRevealed: onAfterAddMorphRevealed,
            ambientInlineEditingActive: ambientInlineEditingActive,
            sectionHostsInlineFocus: sectionHostsInlineFocus,
            onRequestDismissInlineEditing: onRequestDismissInlineEditing,
            inputText: $inputText,
            draggingItemID: $draggingItemID,
            itemReorderHoverTargetItemID: $itemReorderHoverTargetItemID,
            isAddMorphComposerVisible: $isAddMorphComposerVisible,
            progressDots: sectionProgressDots,
            keyboardScrollAnchorID: keyboardScrollAnchorID
        )
        .onAppear {
            updateEditingPulseAnimation()
        }
        .onChange(of: shouldAnimateEditingPulse) { _, _ in
            updateEditingPulseAnimation()
        }
    }

    private var sectionProgressDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(slotStatuses.enumerated()), id: \.offset) { _, status in
                Circle()
                    .fill(dotFill(for: status))
                    .frame(width: dotDiameter(for: status), height: dotDiameter(for: status))
                    .overlay(
                        Circle()
                            .stroke(dotBorder(for: status), lineWidth: dotBorderWidth(for: status))
                    )
                    .overlay {
                        if status == .editing {
                            Circle()
                                .fill(palette.activeEditingAccentStrong)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .overlay {
                        if status == .editing && shouldAnimateEditingPulse {
                            Circle()
                                .stroke(palette.activeEditingAccentStrong.opacity(0.45), lineWidth: 1)
                                .frame(width: 14, height: 14)
                                .scaleEffect(isEditingPulseExpanded ? 1.14 : 0.94)
                                .opacity(isEditingPulseExpanded ? 0 : 0.56)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressAccessibilityLabel)
    }

    private func dotFill(for status: SlotStatus) -> Color {
        switch status {
        case .edited:
            return palette.complete
        case .editing:
            return palette.activeEditingAccent.opacity(0.28)
        case .pending:
            return .clear
        }
    }

    private func dotBorder(for status: SlotStatus) -> Color {
        switch status {
        case .edited:
            return .clear
        case .editing:
            return palette.activeEditingAccentStrong.opacity(0.9)
        case .pending:
            return palette.pendingOutline.opacity(0.52)
        }
    }

    private func dotBorderWidth(for status: SlotStatus) -> CGFloat {
        switch status {
        case .edited:
            return 0
        case .editing:
            return 1.2
        case .pending:
            return 1
        }
    }

    private func dotDiameter(for status: SlotStatus) -> CGFloat {
        status == .editing ? 11.5 : 10
    }

    private func updateEditingPulseAnimation() {
        guard shouldAnimateEditingPulse else {
            isEditingPulseExpanded = false
            return
        }

        isEditingPulseExpanded = false
        withAnimation(.easeOut(duration: 0.82).repeatForever(autoreverses: false)) {
            isEditingPulseExpanded = true
        }
    }
}
