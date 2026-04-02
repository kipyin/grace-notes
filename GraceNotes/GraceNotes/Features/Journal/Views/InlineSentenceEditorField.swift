import SwiftUI
import UIKit

private enum InlineSentenceEditorFieldCopy {
    static let editingAccessibilityHint = String(
        localized:
            "Editing this sentence. Press Done to save, or tap outside the text field."
    )
}

private enum InlineSentenceEditorFieldLayout {
    static let maxVisibleLines = 24
    static let bodyFontName = "SourceSerif4Roman-Regular"
    static let bodyFontSize: CGFloat = 17

    static func bodyUIFont() -> UIFont {
        let baseFont = UIFont(name: bodyFontName, size: bodyFontSize)
            ?? UIFont.preferredFont(forTextStyle: .body)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
    }
}

/// UIKit bridge so Return can submit while the editor still soft-wraps multiple lines.
private struct InlineSentenceEditorTextView: UIViewRepresentable {
    @Binding var text: String
    let isFocused: Bool
    let setFocused: ((Bool) -> Void)?
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityIdentifier: String?
    let isInteractionEnabled: Bool
    let primaryTextUIColor: UIColor
    let onSubmit: () -> Void

    static let minimumHeight = ceil(InlineSentenceEditorFieldLayout.bodyUIFont().lineHeight)

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(frame: .zero)
        configure(textView)
        textView.delegate = context.coordinator
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        configure(uiView)

        if uiView.text != text {
            uiView.text = text
        }

        // UIKit can end editing (scroll-dismiss, keyboard hide) before SwiftUI flips @FocusState.
        // Without this guard, updateUIView keeps re-calling becomeFirstResponder while isFocused is
        // still true, causing begin/end churn and repeated keyboard notifications.
        if !isFocused {
            context.coordinator.suppressBecomeUntilSwiftUIDropsFocus = false
        }

        if isFocused, uiView.isFirstResponder == false {
            if !context.coordinator.suppressBecomeUntilSwiftUIDropsFocus {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused || isInteractionEnabled == false, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context _: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }

        uiView.isScrollEnabled = false
        let fittingSize = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let lineHeight = uiView.font?.lineHeight ?? InlineSentenceEditorFieldLayout.bodyUIFont().lineHeight
        let maxHeight = ceil(lineHeight * CGFloat(InlineSentenceEditorFieldLayout.maxVisibleLines))
        let height = min(max(fittingSize.height, Self.minimumHeight), maxHeight)
        uiView.isScrollEnabled = fittingSize.height > maxHeight
        return CGSize(width: width, height: height)
    }

    private func configure(_ textView: UITextView) {
        textView.backgroundColor = .clear
        textView.font = InlineSentenceEditorFieldLayout.bodyUIFont()
        textView.textColor = primaryTextUIColor
        textView.tintColor = .systemBlue
        textView.isEditable = isInteractionEnabled
        textView.isSelectable = isInteractionEnabled
        textView.adjustsFontForContentSizeCategory = true
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .done
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.accessibilityLabel = accessibilityLabel
        textView.accessibilityHint = accessibilityHint
        textView.accessibilityIdentifier = accessibilityIdentifier
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InlineSentenceEditorTextView

        /// Set when UIKit reports editing ended; cleared when SwiftUI reports `isFocused == false` or on begin.
        var suppressBecomeUntilSwiftUIDropsFocus = false

        init(parent: InlineSentenceEditorTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_: UITextView) {
            suppressBecomeUntilSwiftUIDropsFocus = false
            parent.setFocused?(true)
        }

        func textViewDidEndEditing(_: UITextView) {
            suppressBecomeUntilSwiftUIDropsFocus = true
            parent.setFocused?(false)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn _: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n" else { return true }
            parent.onSubmit()
            return false
        }
    }
}

private struct FocusedWhenLet: ViewModifier {
    let focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

/// Multiline inline editor for strip editing and the add morph composer (shared field behavior).
struct InlineSentenceEditorField: View {
    @Environment(\.todayJournalPalette) private var palette
    let sectionTitle: String
    let placeholder: String
    @Binding var text: String
    let editorIdentifier: String?
    let inputFocus: FocusState<Bool>.Binding?
    let onSubmit: () -> Void
    let isInteractionEnabled: Bool

    private var inputAccessibilityLabel: String {
        String(
            format: String(localized: "%@ editor"),
            locale: Locale.current,
            sectionTitle
        )
    }

    private var focusSetter: ((Bool) -> Void)? {
        guard let inputFocus else { return nil }
        return { isFocused in
            inputFocus.wrappedValue = isFocused
        }
    }

    var body: some View {
        let prompt = Text(placeholder)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(palette.inputPlaceholder)
            .allowsHitTesting(false)

        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                prompt
            }

            InlineSentenceEditorTextView(
                text: $text,
                isFocused: inputFocus?.wrappedValue ?? false,
                setFocused: focusSetter,
                accessibilityLabel: inputAccessibilityLabel,
                accessibilityHint: InlineSentenceEditorFieldCopy.editingAccessibilityHint,
                accessibilityIdentifier: editorIdentifier,
                isInteractionEnabled: isInteractionEnabled,
                primaryTextUIColor: UIColor(palette.textPrimary),
                onSubmit: onSubmit
            )
            .frame(minHeight: InlineSentenceEditorTextView.minimumHeight, alignment: .leading)
        }
        .warmPaperInputStyle()
        .modifier(SequentialSectionStripRow.ConditionalAccessibilityIdentifier(identifier: editorIdentifier))
        .accessibilityLabel(inputAccessibilityLabel)
        .accessibilityHint(InlineSentenceEditorFieldCopy.editingAccessibilityHint)
        .disabled(!isInteractionEnabled)
        .modifier(FocusedWhenLet(focus: inputFocus))
    }
}
