import SwiftUI
import UniformTypeIdentifiers

private enum SequentialSectionPrimaryColumnLayout {
    static let sectionProgressDotsTrailingInset: CGFloat = 8
}

/// Main column of `SequentialSectionView` (guidance, entry rows, text field) split out for type-size limits.
struct SequentialSectionPrimaryColumn<ProgressDots: View>: View {
    @Environment(\.todayJournalPalette) private var palette
    let reduceMotion: Bool
    let title: String
    let addButtonTitle: String
    let addButtonAccessibilityHint: String
    /// When false, the add-row chip omits the trailing chevron (default; matches journal sentence sections).
    let showsTrailingChevronOnAddRow: Bool
    let guidanceTitle: String?
    let guidanceMessage: String?
    let guidanceMessageSecondary: String?
    let items: [Entry]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    let entryAccessibilityIdentifierPrefix: String?
    let addItemAccessibilityIdentifier: String?
    let onboardingState: JournalOnboardingSectionState
    let isTransitioning: Bool
    let editingIndex: Int?
    let inputFocus: FocusState<Bool>.Binding?
    let onInputFocusLost: (() -> Void)?
    let onSubmit: () -> Void
    let onItemTap: (Int) -> Void
    let onMoveItem: ((Int, Int) -> Void)?
    let onDeleteItem: ((Int) -> Void)?
    let onAddNew: (() -> Bool)?
    let onAfterAddMorphRevealed: (() -> Void)?
    let ambientInlineEditingActive: Bool
    let sectionHostsInlineFocus: Bool
    let onRequestDismissInlineEditing: (() -> Void)?

    @Binding var inputText: String
    @Binding var draggingItemID: UUID?
    @Binding var itemReorderHoverTargetItemID: UUID?
    @Binding var isAddMorphComposerVisible: Bool
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var morphingItemID: UUID?
    @State private var lastAcceptedEntryRowTapItemID: UUID?
    @State private var lastAcceptedEntryRowTapDate: Date?

    let progressDots: ProgressDots
    /// When set, `ScrollViewReader` targets chip list + input only (not the section header).
    let keyboardScrollAnchorID: JournalScrollTarget?
}

extension SequentialSectionPrimaryColumn {
    private var activeEditingIndex: Int? {
        guard let editingIndex, items.indices.contains(editingIndex) else { return nil }
        return editingIndex
    }

    private var isInlineEditingActive: Bool {
        activeEditingIndex != nil
    }

    private var isInputFocused: Bool {
        inputFocus?.wrappedValue ?? false
    }

    /// Add control morphs into the composer (same for empty sections and “add another” slots).
    private var showMorphAddSlot: Bool {
        items.count < slotCount
    }

    private var isLockedByGuidance: Bool {
        onboardingState.isLocked
    }

    private var isInteractionEnabled: Bool {
        !isTransitioning && !isLockedByGuidance
    }

    private var ambientGuidanceOpacity: CGFloat {
        ambientInlineEditingActive ? SequentialSectionInlineLayout.ambientUnfocusedOpacity : 1
    }

    private func entryRowOpacityWhenPeerEditing(at index: Int) -> CGFloat {
        guard ambientInlineEditingActive, sectionHostsInlineFocus else { return 1 }
        guard activeEditingIndex != index else { return 1 }
        return SequentialSectionInlineLayout.ambientUnfocusedOpacity
    }

    private var morphSlotAmbientOpacity: CGFloat {
        guard ambientInlineEditingActive else { return 1 }
        guard sectionHostsInlineFocus else { return 1 }
        return isAddMorphComposerVisible ? 1 : SequentialSectionInlineLayout.ambientUnfocusedOpacity
    }

    @ViewBuilder
    private var sentenceListAndMorph: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        itemRow(for: item, at: index)
                    }
                }
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.24),
                    value: editingIndex
                )
            }
            if showMorphAddSlot, let addNew = onAddNew {
                SequentialSectionEntryRow.AddSentenceMorphSlot(
                    sectionTitle: title,
                    addButtonTitle: addButtonTitle,
                    addButtonAccessibilityHint: addButtonAccessibilityHint,
                    accessibilityIdentifier: addItemAccessibilityIdentifier,
                    showsTrailingChevron: showsTrailingChevronOnAddRow,
                    isComposing: isAddMorphComposerVisible,
                    placeholder: placeholder,
                    text: $inputText,
                    reduceMotion: reduceMotion,
                    inputFocus: inputFocus,
                    inputAccessibilityIdentifier: inputAccessibilityIdentifier,
                    onAddTap: { handleAddTap(addNew) },
                    onComposerSubmit: onSubmit,
                    isInteractionEnabled: isInteractionEnabled
                )
                .opacity(morphSlotAmbientOpacity)
                // Scroll target is the composer, not the whole chip column (see `JournalScreen` keyboard scroll).
                .optionalJournalScrollAnchor(isInlineEditingActive ? nil : keyboardScrollAnchorID)
            }
        }
        .allowsHitTesting(isInteractionEnabled)
        .padding(.bottom, showMorphAddSlot ? AppTheme.spacingTight : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                Group {
                    if let guidanceMessage, !guidanceMessage.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                            if let guidanceTitle, !guidanceTitle.isEmpty {
                                Text(guidanceTitle)
                                    .font(AppTheme.warmPaperMetaEmphasis)
                                    .foregroundStyle(AppTheme.accentText)
                            }
                            Text(guidanceMessage)
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let guidanceMessageSecondary {
                                Text(guidanceMessageSecondary)
                                    .font(AppTheme.warmPaperBody)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let guidanceNote = onboardingState.guidanceNote {
                        Text(guidanceNote)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .opacity(ambientGuidanceOpacity)

                HStack {
                    Text(title)
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(onboardingState.titleColor(palette: palette))
                    Spacer(minLength: AppTheme.spacingTight)
                    progressDots
                        .padding(.trailing, SequentialSectionPrimaryColumnLayout.sectionProgressDotsTrailingInset)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isInlineEditingActive {
                        commitInlineEditIfNeeded()
                    } else if isAddMorphComposerVisible, showMorphAddSlot {
                        commitAddMorphFromHeaderTap()
                    }
                }
            }

            if !items.isEmpty || showMorphAddSlot {
                Group {
                    if ambientInlineEditingActive, !sectionHostsInlineFocus {
                        sentenceListAndMorph
                            .opacity(SequentialSectionInlineLayout.ambientUnfocusedOpacity)
                    } else {
                        sentenceListAndMorph
                    }
                }
            }

            if isInlineEditingActive && !showMorphAddSlot {
                Color.clear
                    .frame(height: AppTheme.spacingSection)
            }
        }
        .journalOnboardingSectionStyle(onboardingState, isTransitioning: isTransitioning)
        .overlay {
            if ambientInlineEditingActive, !sectionHostsInlineFocus {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onRequestDismissInlineEditing?()
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isTransitioning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "common.updating"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(palette.textMuted)
                }
                .padding(.horizontal, AppTheme.spacingTight)
                .padding(.vertical, 6)
                .background(palette.paper.opacity(0.92 * palette.sectionPaperOpacity))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(palette.inputBorder.opacity(0.7), lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(
                        format: String(localized: "accessibility.sectionUpdating"),
                        locale: Locale.current,
                        title
                    )
                )
            }
        }
        .onChange(of: isInputFocused) { wasFocused, isFocused in
            guard wasFocused, !isFocused else { return }
            onInputFocusLost?()
            if isAddMorphComposerVisible {
                Task { @MainActor in
                    await Task.yield()
                    let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !isInputFocused, trimmedInput.isEmpty, !isInlineEditingActive {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                            isAddMorphComposerVisible = false
                        }
                    }
                }
            }
        }
        .onChange(of: items.map(\.id)) { _, itemIDs in
            expandedItemIDs.formIntersection(Set(itemIDs))
            if let morphingItemID, !itemIDs.contains(morphingItemID) {
                self.morphingItemID = nil
            }
            if itemIDs.isEmpty {
                isAddMorphComposerVisible = false
            } else if itemIDs.count >= slotCount {
                // Filling the last slot can leave `isAddMorphComposerVisible` true while the morph is not shown;
                // keep header tap / parent state (e.g. `JournalScreen`) consistent with the hidden composer.
                isAddMorphComposerVisible = false
            }
        }
    }

    @ViewBuilder
    private func itemRow(for item: Entry, at index: Int) -> some View {
        if activeEditingIndex == index {
            inlineEditorRow(for: item, at: index)
                .zIndex(2)
                .transition(.identity)
        } else {
            entryRowView(for: item, at: index)
                .opacity(entryRowOpacityWhenPeerEditing(at: index))
                .zIndex(1)
                .transition(.identity)
        }
    }

    @ViewBuilder
    private func entryRowView(for item: Entry, at index: Int) -> some View {
        let rowAccessibilityPrefix = entryAccessibilityIdentifierPrefix.map { "\($0).\(index)" }
        let row = makeSequentialEntryRow(for: item, index: index, rowAccessibilityPrefix: rowAccessibilityPrefix)

        if let onMoveItem, !isInlineEditingActive {
            row
                .onDrag {
                    itemReorderHoverTargetItemID = nil
                    draggingItemID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                } preview: {
                    row
                        .scaleEffect(reduceMotion ? 1 : 1.07)
                        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: SequentialSectionEntryRow.EntryReorderDropDelegate(
                        targetIndex: index,
                        items: items,
                        draggingItemID: $draggingItemID,
                        hoverTargetItemID: $itemReorderHoverTargetItemID,
                        reduceMotion: reduceMotion,
                        onMoveEntry: onMoveItem
                    )
                )
        } else {
            row
        }
    }

    @ViewBuilder
    private func inlineEditorRow(for item: Entry, at index: Int) -> some View {
        let rowAccessibilityPrefix = entryAccessibilityIdentifierPrefix.map { "\($0).\(index)" }
        let editorIdentifier = rowAccessibilityPrefix.map { "\($0).editor" }
        let isMorphing = morphingItemID == item.id

        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            InlineSentenceEditorField(
                sectionTitle: title,
                placeholder: placeholder,
                text: $inputText,
                editorIdentifier: editorIdentifier,
                inputFocus: inputFocus,
                onSubmit: { commitInlineEditIfNeeded() },
                isInteractionEnabled: isInteractionEnabled
            )
        }
        .padding(.horizontal, SequentialSectionInlineLayout.editorMorphHorizontalInset)
        .offset(
            y: isMorphing
                ? 2
                : SequentialSectionInlineLayout.editorMorphVerticalOffset
        )
        .scaleEffect(
            x: reduceMotion ? 1 : (isMorphing ? 1 : 1.02),
            y: 1,
            anchor: .center
        )
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.22),
            value: morphingItemID
        )
        .padding(.bottom, SequentialSectionInlineLayout.editorBottomSpacing)
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
        .optionalJournalScrollAnchor(keyboardScrollAnchorID)
    }

    private func commitInlineEditIfNeeded() {
        guard isInlineEditingActive else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            onSubmit()
        }
    }

    /// Issue #275: Commit prior editor state (`onAddNew` / `handleAddEntryTap`) before revealing the morph so we
    /// never show the composer when the handler fails or `isTransitioning` blocks interaction.
    private func handleAddTap(_ addNew: () -> Bool) {
        guard addNew() else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            isAddMorphComposerVisible = true
        }
        if let onAfterAddMorphRevealed {
            Task { @MainActor in
                await Task.yield()
                onAfterAddMorphRevealed()
            }
        }
    }

    private func commitAddMorphFromHeaderTap() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                isAddMorphComposerVisible = false
            }
            inputFocus?.wrappedValue = false
        } else {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                onSubmit()
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalJournalScrollAnchor(_ id: JournalScrollTarget?) -> some View {
        if let id {
            self.id(id)
        } else {
            self
        }
    }
}

private extension SequentialSectionPrimaryColumn {
    func makeSequentialEntryRow(
        for item: Entry,
        index: Int,
        rowAccessibilityPrefix: String?
    ) -> SequentialEntryRowView {
        let isExpandable = SequentialEntryRowView.requiresExpandedPreview(item.fullText)
        return SequentialEntryRowView(
            sectionTitle: title,
            itemPosition: index + 1,
            itemCount: items.count,
            sentence: item.fullText,
            accessibilityIdentifier: rowAccessibilityPrefix,
            isSelected: editingIndex == index,
            isExpanded: expandedItemIDs.contains(item.id),
            isExpandable: isExpandable,
            expansionAccessibilityIdentifier: rowAccessibilityPrefix.map { "\($0).more" },
            onTap: { handleItemTap(index: index, itemID: item.id) },
            onToggleExpanded: isExpandable ? {
                if expandedItemIDs.contains(item.id) {
                    expandedItemIDs.remove(item.id)
                } else {
                    expandedItemIDs.insert(item.id)
                }
            } : nil,
            onDelete: onDeleteItem.map { handler in { handler(index) } }
        )
    }

    func handleItemTap(index: Int, itemID: UUID) {
        let now = Date()
        guard EntryRowTapDebounce.shouldProcessTap(
            itemID: itemID,
            at: now,
            lastAcceptedItemID: &lastAcceptedEntryRowTapItemID,
            lastAcceptedDate: &lastAcceptedEntryRowTapDate,
            interval: EntryRowTapDebounce.sameRowTapDebounceInterval
        ) else { return }

        morphingItemID = itemID
        if isAddMorphComposerVisible {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                isAddMorphComposerVisible = false
            }
        }
        onItemTap(index)
        Task { @MainActor in
            await Task.yield()
            if morphingItemID == itemID {
                morphingItemID = nil
            }
        }
    }
}
