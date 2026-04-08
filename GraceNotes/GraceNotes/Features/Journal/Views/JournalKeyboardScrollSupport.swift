import SwiftUI
import UIKit

enum JournalKeyWindowReader {
    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

/// Stable `ScrollViewReader` targets for Today journal keyboard avoidance.
enum JournalScrollTarget: String, CaseIterable {
    /// Journal date + completion header (`DateSectionView`).
    case completionHeader
    case sentenceSections
    case gratitudeSection
    /// Chips + composer only (not section title/guidance) so keyboard scroll aligns the field, not the whole block.
    case needInputArea
    case peopleInputArea
    case readingNotes
    case reflections
}

enum JournalKeyboardScrollReason {
    case keyboardDidChangeFrame
    case focusChanged(JournalScrollTarget)
    case typing(JournalScrollTarget)
    case newlineAdded(JournalScrollTarget)

    var explicitTarget: JournalScrollTarget? {
        switch self {
        case .keyboardDidChangeFrame:
            return nil
        case let .focusChanged(target), let .typing(target), let .newlineAdded(target):
            return target
        }
    }

    var usesTypingDrivenScroll: Bool {
        switch self {
        case .typing:
            return true
        default:
            return false
        }
    }
}

/// Hybrid margin: scales with body line height (Dynamic Type) with a floor so the gap never collapses.
enum JournalKeyboardScrollMetrics {
    static func comfortMarginAboveKeyboard() -> CGFloat {
        let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
        let scaled = lineHeight + AppTheme.spacingTight
        return max(AppTheme.spacingRegular, scaled)
    }

    /// Caps Reading Notes / Reflections `TextEditor` height so long text scrolls inside the control.
    /// The outer journal `ScrollView` can then avoid pinning the whole section with `scrollTo` on every keystroke,
    /// which was pushing the caret off the top while the field bottom stayed above the keyboard.
    static func notesTextEditorMaxHeight() -> CGFloat {
        guard let window = JournalKeyWindowReader.keyWindow() else {
            return 320
        }
        let height = window.bounds.height
        return min(480, max(200, height * 0.36))
    }
}

/// Keyboard overlap with the key window; sizes extra scroll affordance without guessing global safe-area behavior.
enum JournalKeyboardOverlapReader {
    static func overlapHeight(from notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        guard let window = JournalKeyWindowReader.keyWindow() else {
            return 0
        }
        let keyboardInWindow = window.convert(frame, from: nil)
        return max(0, window.bounds.intersection(keyboardInWindow).height)
    }
}

struct JournalScrollBottomSafeAreaPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Uses the first responder's caret (when available) so we don't call `scrollTo` when typing position is already
/// comfortably above the keyboard — `scrollTo` anchors to entire section IDs and can over-correct on field switches.
enum JournalCaretVisibilityReader {
    /// When `true`, skip programmatic `scrollTo`; UIKit/SwiftUI already has the caret in a comfortable position.
    static func shouldSkipAutoScroll(keyboardOverlapHeight: CGFloat, comfortMargin: CGFloat) -> Bool {
        guard keyboardOverlapHeight > 0,
              let window = JournalKeyWindowReader.keyWindow() else { return false }
        let keyboardTopY = window.bounds.height - keyboardOverlapHeight
        let caretLowestY = caretMaxYInWindow()
        guard let caretLowestY else { return false }
        return caretLowestY <= keyboardTopY - comfortMargin - 0.5
    }

    /// Scrolls the first responder `UITextView`'s **content** so the caret stays visible when lines wrap or grow.
    /// Used for Reading Notes / Reflections (`TextEditor`); callers should only invoke when that field is focused.
    /// Outer `scrollTo(anchor: .bottom)` aligns the **frame**; this aligns the **insertion point** inside the editor.
    static func nudgeFirstResponderUITextViewCaretIntoVisibleContent() {
        guard let window = JournalKeyWindowReader.keyWindow(),
              let textView = findFirstResponder(in: window) as? UITextView,
              let range = textView.selectedTextRange else { return }
        var rect = textView.caretRect(for: range.end)
        if rect.height < 1 {
            let line = textView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
            rect.size.height = max(line, 18)
        }
        let verticalPad = max(8, JournalKeyboardScrollMetrics.comfortMarginAboveKeyboard() * 0.4)
        rect = rect.insetBy(dx: -4, dy: -verticalPad)
        textView.scrollRectToVisible(rect, animated: false)
    }

    private static func caretMaxYInWindow() -> CGFloat? {
        guard let window = JournalKeyWindowReader.keyWindow(),
              let responder = findFirstResponder(in: window) else { return nil }
        let caretInWindow: CGRect?
        if let textView = responder as? UITextView, let range = textView.selectedTextRange {
            let local = textView.caretRect(for: range.end)
            caretInWindow = textView.convert(local, to: nil)
        } else if let textField = responder as? UITextField, let range = textField.selectedTextRange {
            let local = textField.caretRect(for: range.end)
            caretInWindow = textField.convert(local, to: nil)
        } else {
            caretInWindow = nil
        }
        guard let caretInWindow,
              !caretInWindow.isNull,
              !caretInWindow.isInfinite,
              caretInWindow.width.isFinite,
              caretInWindow.height.isFinite else { return nil }
        if caretInWindow == .zero { return nil }
        return caretInWindow.maxY
    }

    private static func findFirstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = findFirstResponder(in: subview) {
                return found
            }
        }
        return nil
    }
}

/// Drives when inner `UITextView` caret nudging runs relative to outer `ScrollViewReader` scrolling.
enum JournalKeyboardScrollDomain: Equatable {
    case sentenceChips
    case notesMultiline

    static func domain(for scrollTarget: JournalScrollTarget) -> JournalKeyboardScrollDomain {
        switch scrollTarget {
        case .readingNotes, .reflections:
            return .notesMultiline
        case .completionHeader, .gratitudeSection, .needInputArea, .peopleInputArea, .sentenceSections:
            return .sentenceChips
        }
    }
}

/// Parameters for `JournalKeyboardScrollCoordinator.scheduleScrollAdjust`.
struct JournalKeyboardScrollRequest {
    let proxy: ScrollViewProxy
    let reason: JournalKeyboardScrollReason
    let scrollTarget: JournalScrollTarget
    let keyboardOverlapHeight: CGFloat
    let reduceMotion: Bool
    let showAppTour: Bool
}

/// Single entry point for Today keyboard scroll policy (outer `scrollTo`, overlap jitter, notes caret nudge).
enum JournalKeyboardScrollCoordinator {
    /// Ignore sub-point fluctuations in computed keyboard overlap when the keyboard is already fully presented.
    static let keyboardOverlapJitterEpsilon: CGFloat = 1.5

    /// Whether a change in `keyboardOverlapHeight` should schedule a scroll adjustment (show/hide or real resize).
    static func shouldScheduleScrollAfterOverlapChange(oldOverlap: CGFloat, newOverlap: CGFloat) -> Bool {
        let jitter = abs(newOverlap - oldOverlap)
        return oldOverlap == 0 || newOverlap == 0 || jitter >= keyboardOverlapJitterEpsilon
    }

    static func scrollAnchor(
        for reason: JournalKeyboardScrollReason,
        scrollTarget: JournalScrollTarget
    ) -> UnitPoint {
        switch reason {
        case .focusChanged:
            switch scrollTarget {
            case .gratitudeSection, .needInputArea, .peopleInputArea:
                return .center
            case .completionHeader, .sentenceSections, .readingNotes, .reflections:
                return .bottom
            }
        case .keyboardDidChangeFrame, .typing, .newlineAdded:
            return .bottom
        }
    }

    @MainActor
    static func scheduleScrollAdjust(
        request: JournalKeyboardScrollRequest,
        existingTask: inout Task<Void, Never>?
    ) {
        existingTask?.cancel()
        let usesTypingDrivenScroll = request.reason.usesTypingDrivenScroll
        let animation: Animation?
        if usesTypingDrivenScroll {
            animation = nil
        } else {
            animation = request.reduceMotion ? nil : .easeOut(duration: 0.25)
        }
        let scrollTarget = request.scrollTarget
        let anchor = scrollAnchor(for: request.reason, scrollTarget: scrollTarget)
        let domain = JournalKeyboardScrollDomain.domain(for: scrollTarget)
        let keyboardOverlap = request.keyboardOverlapHeight
        let appTourShowing = request.showAppTour
        let proxy = request.proxy
        existingTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard !appTourShowing else { return }
            let comfort = JournalKeyboardScrollMetrics.comfortMarginAboveKeyboard()
            if domain == .notesMultiline {
                JournalCaretVisibilityReader.nudgeFirstResponderUITextViewCaretIntoVisibleContent()
            }
            let skipForCaret = JournalCaretVisibilityReader.shouldSkipAutoScroll(
                keyboardOverlapHeight: keyboardOverlap,
                comfortMargin: comfort
            )
            guard !skipForCaret else { return }
            if let animation {
                withAnimation(animation) {
                    proxy.scrollTo(scrollTarget, anchor: anchor)
                }
            } else {
                proxy.scrollTo(scrollTarget, anchor: anchor)
            }
            if domain == .notesMultiline {
                await Task.yield()
                JournalCaretVisibilityReader.nudgeFirstResponderUITextViewCaretIntoVisibleContent()
            }
        }
    }
}
