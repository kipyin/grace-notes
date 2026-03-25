import SwiftUI

struct SequentialSectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    /// Guided onboarding title shown above the section header (optional; omitted when empty).
    let guidanceTitle: String?
    /// Guided onboarding message shown under `guidanceTitle`.
    let guidanceMessage: String?
    /// Optional second line under `guidanceMessage` (e.g. keyboard hint).
    let guidanceMessageSecondary: String?
    let items: [JournalItem]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    /// When set (e.g. UI tests), chips use identifiers `"\(prefix).\(index)"` for stable XCUITest queries.
    let chipAccessibilityIdentifierPrefix: String?
    /// When set (e.g. UI tests), the section (+) control exposes this `accessibilityIdentifier`.
    let addChipAccessibilityIdentifier: String?
    let onboardingState: JournalOnboardingSectionState
    let isTransitioning: Bool
    @Binding var inputText: String
    let editingIndex: Int?
    let inputFocus: FocusState<Bool>.Binding?
    /// Fires when the chip field loses focus; handler ignores empty drafts.
    let onInputFocusLost: (() -> Void)?
    let onSubmit: () -> Void
    let onChipTap: (Int) -> Void
    let onRenameChip: ((Int, String) -> Void)?
    let onMoveChip: ((Int, Int) -> Void)?
    let onDeleteChip: ((Int) -> Void)?
    let onAddNew: (() -> Void)?
    @State private var draggingItemID: UUID?
    /// Chip UUID that last triggered a live reorder during this drag.
    /// Skips redundant `dropUpdated` work when indices shift but the finger stays on the same chip.
    @State private var chipReorderHoverTargetItemID: UUID?
    @State private var chipScrollSnapshot = ChipRowScrollSnapshot(
        metrics: HorizontalScrollMetrics(),
        elasticDeltaX: 0,
        elasticDeltaY: 0
    )
    @State private var isEditingPulseExpanded = false

    init(
        title: String,
        guidanceTitle: String? = nil,
        guidanceMessage: String? = nil,
        guidanceMessageSecondary: String? = nil,
        items: [JournalItem],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        chipAccessibilityIdentifierPrefix: String? = nil,
        addChipAccessibilityIdentifier: String? = nil,
        onboardingState: JournalOnboardingSectionState = .standard,
        isTransitioning: Bool = false,
        inputText: Binding<String>,
        editingIndex: Int?,
        inputFocus: FocusState<Bool>.Binding? = nil,
        onInputFocusLost: (() -> Void)? = nil,
        onSubmit: @escaping () -> Void,
        onChipTap: @escaping (Int) -> Void,
        onRenameChip: ((Int, String) -> Void)? = nil,
        onMoveChip: ((Int, Int) -> Void)? = nil,
        onDeleteChip: ((Int) -> Void)? = nil,
        onAddNew: (() -> Void)? = nil
    ) {
        self.title = title
        self.guidanceTitle = guidanceTitle
        self.guidanceMessage = guidanceMessage
        self.guidanceMessageSecondary = guidanceMessageSecondary
        self.items = items
        self.placeholder = placeholder
        self.slotCount = slotCount
        self.inputAccessibilityIdentifier = inputAccessibilityIdentifier
        self.chipAccessibilityIdentifierPrefix = chipAccessibilityIdentifierPrefix
        self.addChipAccessibilityIdentifier = addChipAccessibilityIdentifier
        self.onboardingState = onboardingState
        self.isTransitioning = isTransitioning
        self._inputText = inputText
        self.editingIndex = editingIndex
        self.inputFocus = inputFocus
        self.onInputFocusLost = onInputFocusLost
        self.onSubmit = onSubmit
        self.onChipTap = onChipTap
        self.onRenameChip = onRenameChip
        self.onMoveChip = onMoveChip
        self.onDeleteChip = onDeleteChip
        self.onAddNew = onAddNew
    }

    private var isInputFocused: Bool {
        inputFocus?.wrappedValue ?? false
    }

    private var shouldAnimateEditingPulse: Bool {
        isInputFocused && !reduceMotion
    }

    private var slotStatuses: [SequentialSectionSlotStatus] {
        (0..<slotCount).map { index in
            if editingIndex == index {
                return .editing
            }
            if index < items.count {
                return .edited
            }
            return .pending
        }
    }

    private var progressAccessibilityLabel: String {
        let editedCount = slotStatuses.filter { $0 == .edited }.count
        let editingCount = slotStatuses.filter { $0 == .editing }.count
        let pendingCount = slotStatuses.filter { $0 == .pending }.count
        return String(
            format: String(localized: "%1$@ progress. %2$d complete, %3$d in progress, %4$d open."),
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
            guidanceTitle: guidanceTitle,
            guidanceMessage: guidanceMessage,
            guidanceMessageSecondary: guidanceMessageSecondary,
            items: items,
            placeholder: placeholder,
            slotCount: slotCount,
            inputAccessibilityIdentifier: inputAccessibilityIdentifier,
            chipAccessibilityIdentifierPrefix: chipAccessibilityIdentifierPrefix,
            addChipAccessibilityIdentifier: addChipAccessibilityIdentifier,
            onboardingState: onboardingState,
            isTransitioning: isTransitioning,
            editingIndex: editingIndex,
            inputFocus: inputFocus,
            onInputFocusLost: onInputFocusLost,
            onSubmit: onSubmit,
            onChipTap: onChipTap,
            onRenameChip: onRenameChip,
            onMoveChip: onMoveChip,
            onDeleteChip: onDeleteChip,
            onAddNew: onAddNew,
            inputText: $inputText,
            chipScrollSnapshot: $chipScrollSnapshot,
            draggingItemID: $draggingItemID,
            chipReorderHoverTargetItemID: $chipReorderHoverTargetItemID,
            progressDots: sectionProgressDots
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
                                .fill(AppTheme.journalActiveEditingAccentStrong)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .overlay {
                        if status == .editing && shouldAnimateEditingPulse {
                            Circle()
                                .stroke(AppTheme.journalActiveEditingAccentStrong.opacity(0.45), lineWidth: 1)
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

    private func dotFill(for status: SequentialSectionSlotStatus) -> Color {
        switch status {
        case .edited:
            return AppTheme.journalComplete
        case .editing:
            return AppTheme.journalActiveEditingAccent.opacity(0.28)
        case .pending:
            return .clear
        }
    }

    private func dotBorder(for status: SequentialSectionSlotStatus) -> Color {
        switch status {
        case .edited:
            return .clear
        case .editing:
            return AppTheme.journalActiveEditingAccentStrong.opacity(0.9)
        case .pending:
            return AppTheme.journalPendingOutline.opacity(0.52)
        }
    }

    private func dotBorderWidth(for status: SequentialSectionSlotStatus) -> CGFloat {
        switch status {
        case .edited:
            return 0
        case .editing:
            return 1.2
        case .pending:
            return 1
        }
    }

    private func dotDiameter(for status: SequentialSectionSlotStatus) -> CGFloat {
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
