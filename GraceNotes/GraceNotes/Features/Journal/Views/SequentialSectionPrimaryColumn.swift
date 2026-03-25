import SwiftUI
import UniformTypeIdentifiers

enum SequentialSectionSlotStatus {
    case edited
    case editing
    case pending
}

/// Main column of `SequentialSectionView` (guidance, chip scroller, text field) split out for type-size limits.
struct SequentialSectionPrimaryColumn<ProgressDots: View>: View {
    let reduceMotion: Bool
    let title: String
    let guidanceTitle: String?
    let guidanceMessage: String?
    let guidanceMessageSecondary: String?
    let items: [JournalItem]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    let chipAccessibilityIdentifierPrefix: String?
    let addChipAccessibilityIdentifier: String?
    let onboardingState: JournalOnboardingSectionState
    let isTransitioning: Bool
    let editingIndex: Int?
    let inputFocus: FocusState<Bool>.Binding?
    let onInputFocusLost: (() -> Void)?
    let onSubmit: () -> Void
    let onChipTap: (Int) -> Void
    let onRenameChip: ((Int, String) -> Void)?
    let onMoveChip: ((Int, Int) -> Void)?
    let onDeleteChip: ((Int) -> Void)?
    let onAddNew: (() -> Void)?

    @Binding var inputText: String
    @Binding var chipScrollSnapshot: ChipRowScrollSnapshot
    @Binding var draggingItemID: UUID?
    @Binding var chipReorderHoverTargetItemID: UUID?

    let progressDots: ProgressDots

    private static let sectionProgressDotsTrailingInset: CGFloat = 8

    private var showInput: Bool {
        items.count < slotCount || editingIndex != nil
    }

    private var isInputFocused: Bool {
        inputFocus?.wrappedValue ?? false
    }

    private var showAddChip: Bool {
        guard onAddNew != nil, !items.isEmpty else { return false }
        return items.count < slotCount
    }

    private var isLockedByGuidance: Bool {
        onboardingState.isLocked
    }

    private var isInteractionEnabled: Bool {
        !isTransitioning && !isLockedByGuidance
    }

    private var canScrollChipsLeft: Bool {
        canScrollLeft(for: chipScrollSnapshot.metrics)
    }

    private var canScrollChipsRight: Bool {
        canScrollRight(for: chipScrollSnapshot.metrics)
    }

    private var inputAccessibilityLabel: String {
        String(
            format: String(localized: "%@ input"),
            locale: Locale.current,
            title
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                if let guidanceMessage, !guidanceMessage.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                        if let guidanceTitle, !guidanceTitle.isEmpty {
                            Text(guidanceTitle)
                                .font(AppTheme.warmPaperMetaEmphasis)
                                .foregroundStyle(AppTheme.accentText)
                        }
                        Text(guidanceMessage)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.journalTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let guidanceMessageSecondary {
                            Text(guidanceMessageSecondary)
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.journalTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let guidanceNote = onboardingState.guidanceNote {
                    Text(guidanceNote)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.journalTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(title)
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(onboardingState.titleColor)
                    Spacer(minLength: AppTheme.spacingTight)
                    progressDots
                        .padding(.trailing, Self.sectionProgressDotsTrailingInset)
                }
            }

            if !items.isEmpty || showAddChip {
                SequentialSectionChipScroller(
                    reduceMotion: reduceMotion,
                    title: title,
                    showAddChip: showAddChip,
                    addChipAccessibilityIdentifier: addChipAccessibilityIdentifier,
                    isInteractionEnabled: isInteractionEnabled,
                    canScrollChipsLeft: canScrollChipsLeft,
                    canScrollChipsRight: canScrollChipsRight,
                    onAddNew: onAddNew,
                    chipScrollSnapshot: $chipScrollSnapshot
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        chipView(for: item, at: index)
                    }
                }
            }

            if showInput {
                if let inputFocus {
                    TextField(
                        "",
                        text: $inputText,
                        prompt: Text(placeholder)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.journalInputPlaceholder)
                    )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.journalTextPrimary)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { onSubmit() }
                        .focused(inputFocus)
                        .warmPaperInputStyle()
                        .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
                        .accessibilityLabel(inputAccessibilityLabel)
                        .accessibilityHint(placeholder)
                        .disabled(!isInteractionEnabled)
                } else {
                    TextField(
                        "",
                        text: $inputText,
                        prompt: Text(placeholder)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.journalInputPlaceholder)
                    )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.journalTextPrimary)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { onSubmit() }
                        .warmPaperInputStyle()
                        .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
                        .accessibilityLabel(inputAccessibilityLabel)
                        .accessibilityHint(placeholder)
                        .disabled(!isInteractionEnabled)
                }
            }
        }
        .journalOnboardingSectionStyle(onboardingState, isTransitioning: isTransitioning)
        .overlay(alignment: .topTrailing) {
            if isTransitioning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Updating…"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.journalTextMuted)
                }
                .padding(.horizontal, AppTheme.spacingTight)
                .padding(.vertical, 6)
                .background(AppTheme.journalPaper.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.journalInputBorder.opacity(0.7), lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(
                        format: String(localized: "%@ section is updating."),
                        locale: Locale.current,
                        title
                    )
                )
            }
        }
        .onChange(of: isInputFocused) { wasFocused, isFocused in
            guard let onInputFocusLost else { return }
            if wasFocused, !isFocused {
                onInputFocusLost()
            }
        }
    }

    @ViewBuilder
    private func chipView(for item: JournalItem, at index: Int) -> some View {
        let chipIdentifier = chipAccessibilityIdentifierPrefix.map { "\($0).\(index)" }
        let chip = ChipView(
            label: item.displayLabel,
            isTruncated: item.isTruncated,
            isSelected: editingIndex == index,
            onTap: { onChipTap(index) },
            onRenameLabel: onRenameChip.map { handler in { handler(index, $0) } },
            onDelete: onDeleteChip.map { handler in { handler(index) } }
        )

        if let onMoveChip {
            chip
                .modifier(ConditionalAccessibilityIdentifier(identifier: chipIdentifier))
                .onDrag {
                    chipReorderHoverTargetItemID = nil
                    draggingItemID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                } preview: {
                    chip
                        .scaleEffect(reduceMotion ? 1 : 1.07)
                        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ChipReorderDropDelegate(
                        targetIndex: index,
                        items: items,
                        draggingItemID: $draggingItemID,
                        hoverTargetItemID: $chipReorderHoverTargetItemID,
                        reduceMotion: reduceMotion,
                        onMoveChip: onMoveChip
                    )
                )
        } else {
            chip
                .modifier(ConditionalAccessibilityIdentifier(identifier: chipIdentifier))
        }
    }

    private func canScrollLeft(for metrics: HorizontalScrollMetrics) -> Bool {
        metrics.contentOffsetX > 1
    }

    private func canScrollRight(for metrics: HorizontalScrollMetrics) -> Bool {
        let remaining = metrics.contentWidth - (metrics.contentOffsetX + metrics.viewportWidth)
        return remaining > 1
    }
}
