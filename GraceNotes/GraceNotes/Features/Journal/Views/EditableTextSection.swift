import SwiftUI

/// A section with a title and multiline TextEditor. Used for Reading Notes and Reflections.
struct EditableTextSection: View {
    let title: String
    let guidanceTitle: String?
    let guidanceMessage: String?
    let guidanceMessageSecondary: String?
    @Binding var text: String
    let minHeight: CGFloat
    let onboardingState: JournalOnboardingSectionState
    let inputFocus: FocusState<Bool>.Binding?

    init(
        title: String,
        guidanceTitle: String? = nil,
        guidanceMessage: String? = nil,
        guidanceMessageSecondary: String? = nil,
        text: Binding<String>,
        minHeight: CGFloat = 120,
        onboardingState: JournalOnboardingSectionState = .standard,
        inputFocus: FocusState<Bool>.Binding? = nil
    ) {
        self.title = title
        self.guidanceTitle = guidanceTitle
        self.guidanceMessage = guidanceMessage
        self.guidanceMessageSecondary = guidanceMessageSecondary
        self._text = text
        self.minHeight = minHeight
        self.onboardingState = onboardingState
        self.inputFocus = inputFocus
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

            Text(title)
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(onboardingState.titleColor)
            textEditor
        }
        .journalOnboardingSectionStyle(onboardingState)
    }

    @ViewBuilder
    private var textEditor: some View {
        let editor = TextEditor(text: $text)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.journalTextPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: minHeight)
            .warmPaperInputStyle()
            .disabled(onboardingState.isLocked)
            .accessibilityLabel(
                String(
                    format: String(localized: "%@ text"),
                    locale: Locale.current,
                    title
                )
            )
            .accessibilityHint(
                String(
                    format: String(localized: "Write your %@ here."),
                    locale: Locale.current,
                    title
                )
            )
        if let inputFocus {
            editor.focused(inputFocus)
        } else {
            editor
        }
    }
}
