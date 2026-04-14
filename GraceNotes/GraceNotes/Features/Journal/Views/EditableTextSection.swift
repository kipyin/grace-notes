import SwiftUI

/// A section with a title and multiline TextEditor. Used for Reading Notes and Reflections.
struct EditableTextSection: View {
    @Environment(\.todayJournalPalette) private var palette
    @State private var storedNewlineCount = 0
    let title: String
    let guidanceTitle: String?
    let guidanceMessage: String?
    let guidanceMessageSecondary: String?
    @Binding var text: String
    let minHeight: CGFloat
    let onboardingState: JournalOnboardingSectionState
    let inputFocus: FocusState<Bool>.Binding?
    /// When set, `ScrollViewReader` targets the text editor only (not guidance chrome or title).
    let keyboardScrollAnchorID: JournalScrollTarget?
    /// Called when a newline is inserted (Return) so the parent can scroll multiline editors above the keyboard.
    let onMultilineLineAdded: (() -> Void)?

    init(
        title: String,
        guidanceTitle: String? = nil,
        guidanceMessage: String? = nil,
        guidanceMessageSecondary: String? = nil,
        text: Binding<String>,
        minHeight: CGFloat = 120,
        onboardingState: JournalOnboardingSectionState = .standard,
        inputFocus: FocusState<Bool>.Binding? = nil,
        keyboardScrollAnchorID: JournalScrollTarget? = nil,
        onMultilineLineAdded: (() -> Void)? = nil
    ) {
        self.title = title
        self.guidanceTitle = guidanceTitle
        self.guidanceMessage = guidanceMessage
        self.guidanceMessageSecondary = guidanceMessageSecondary
        self._text = text
        self.minHeight = minHeight
        self.onboardingState = onboardingState
        self.inputFocus = inputFocus
        self.keyboardScrollAnchorID = keyboardScrollAnchorID
        self.onMultilineLineAdded = onMultilineLineAdded
    }

    var body: some View {
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

            Text(title)
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(onboardingState.titleColor(palette: palette))
            textEditor
                .onChange(of: text) { _, newValue in
                    let newCount = newValue.filter { $0 == "\n" }.count
                    // `nudgeFirstResponderUITextViewCaretIntoVisibleContent` affects whichever UITextView is first
                    // responder; only react when this section owns focus (or no focus binding is provided).
                    let isThisFieldFocused = inputFocus?.wrappedValue ?? true
                    if let onMultilineLineAdded, isThisFieldFocused, newCount > storedNewlineCount {
                        onMultilineLineAdded()
                    }
                    storedNewlineCount = newCount
                    if isThisFieldFocused {
                        Task { @MainActor in
                            await Task.yield()
                            JournalCaretVisibilityReader.nudgeFirstResponderUITextViewCaretIntoVisibleContent()
                        }
                    }
                }
        }
        .onAppear {
            storedNewlineCount = text.filter { $0 == "\n" }.count
        }
        .journalOnboardingSectionStyle(onboardingState)
    }

    @ViewBuilder
    private func keyboardScrollAnchoredEditor<Content: View>(_ content: Content) -> some View {
        if let keyboardScrollAnchorID {
            content.id(keyboardScrollAnchorID)
        } else {
            content
        }
    }

    @ViewBuilder
    private var textEditor: some View {
        let editor = TextEditor(text: $text)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(palette.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .frame(maxHeight: JournalKeyboardScrollMetrics.notesTextEditorMaxHeight())
            .warmPaperInputStyle()
            .disabled(onboardingState.isLocked)
            .accessibilityLabel(
                String(
                    format: String(localized: "accessibility.sectionTextLabel"),
                    locale: Locale.current,
                    title
                )
            )
            .accessibilityHint(
                String(
                    format: String(localized: "journal.editor.placeholderSection"),
                    locale: Locale.current,
                    title
                )
            )
        if let inputFocus {
            keyboardScrollAnchoredEditor(editor).focused(inputFocus)
        } else {
            keyboardScrollAnchoredEditor(editor)
        }
    }
}
