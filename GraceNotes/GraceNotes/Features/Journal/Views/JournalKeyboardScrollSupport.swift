import os
import SwiftUI
import UIKit

enum JournalKeyWindowReader {
    /// Prefer the foreground-active scene so Stage Manager / multi-window iPad does not pair keyboard or caret
    /// geometry with another scene's window (`connectedScenes` order is undefined).
    static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let foreground = scenes.first(where: { $0.activationState == .foregroundActive }) {
            if let key = foreground.keyWindow ?? foreground.windows.first(where: \.isKeyWindow) {
                return key
            }
        }
        return scenes
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
    private static let logger = Logger(
        subsystem: "com.gracenotes.GraceNotes",
        category: "JournalKeyboardScroll"
    )

    static func overlapHeight(from notification: Notification) -> CGFloat {
        guard let frame = keyboardFrameEnd(from: notification) else {
            return 0
        }
        guard let window = JournalKeyWindowReader.keyWindow() else {
            return 0
        }
        let keyboardInWindow = window.convert(frame, from: nil)
        return max(0, window.bounds.intersection(keyboardInWindow).height)
    }

    /// `keyboardFrameEndUserInfoKey` is documented as an `NSValue` wrapping `CGRect`; a bare `as? CGRect` often fails.
    private static func keyboardFrameEnd(from notification: Notification) -> CGRect? {
        guard let raw = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] else {
            return nil
        }
        if let rect = raw as? CGRect {
            return rect
        }
        if let value = raw as? NSValue {
            return value.cgRectValue
        }
        logUnrecognizedKeyboardFrameUserInfoValue(raw)
        return nil
    }

    private static func logUnrecognizedKeyboardFrameUserInfoValue(_ raw: Any) {
        let typeName = String(describing: type(of: raw))
        #if DEBUG
        assertionFailure("Keyboard frame end userInfo value had unexpected type: \(typeName)")
        #endif
        logger.warning("Keyboard frame end userInfo value had unexpected type: \(typeName, privacy: .public)")
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
              let responder = findFirstResponder(in: window),
              let textView = nearestTextView(from: responder),
              let range = textView.selectedTextRange else { return }
        var rect = textView.caretRect(for: range.end)
        if rect.height < 1 {
            let line = textView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
            rect.size.height = max(line, 18)
        }
        let verticalPad = max(8, JournalKeyboardScrollMetrics.comfortMarginAboveKeyboard() * 0.4)
        rect = rect.insetBy(dx: -4, dy: -verticalPad)
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.size.width.isFinite, rect.size.height.isFinite,
              !rect.isNull, !rect.isInfinite else { return }
        textView.scrollRectToVisible(rect, animated: false)
    }

    private static func caretMaxYInWindow() -> CGFloat? {
        guard let window = JournalKeyWindowReader.keyWindow(),
              let responder = findFirstResponder(in: window) else { return nil }
        let caretInWindow: CGRect?
        if let textView = nearestTextView(from: responder), let range = textView.selectedTextRange {
            let local = textView.caretRect(for: range.end)
            caretInWindow = textView.convert(local, to: nil)
        } else if let textField = nearestTextField(from: responder), let range = textField.selectedTextRange {
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

    /// First responder is sometimes an internal subview; walk up to the `UITextView` that owns the caret APIs.
    /// Skips an outer `UITextView` when a `UITextField` owns first responder (nested controls). Only accepts an
    /// ancestor `UITextView` when the responder lies inside that view’s bounds in local coordinates.
    private static func nearestTextView(from view: UIView) -> UITextView? {
        if let direct = view as? UITextView {
            return direct
        }
        if view is UITextField {
            return nil
        }
        let responder = view
        var current: UIView? = view.superview
        while let node = current {
            if let textView = node as? UITextView {
                let originInTextView = textView.convert(responder.bounds.origin, from: responder)
                if responder.isDescendant(of: textView), textView.bounds.contains(originInTextView) {
                    return textView
                }
            }
            current = node.superview
        }
        return nil
    }

    /// Same as `nearestTextView` but for single-line fields (`UITextField` and common subclasses).
    /// Skips an outer `UITextField` when a `UITextView` owns first responder. Only accepts an ancestor field when
    /// the responder lies inside that field’s bounds in local coordinates.
    private static func nearestTextField(from view: UIView) -> UITextField? {
        if let direct = view as? UITextField {
            return direct
        }
        if view is UITextView {
            return nil
        }
        let responder = view
        var current: UIView? = view.superview
        while let node = current {
            if let textField = node as? UITextField {
                let originInField = textField.convert(responder.bounds.origin, from: responder)
                if responder.isDescendant(of: textField), textField.bounds.contains(originInField) {
                    return textField
                }
            }
            current = node.superview
        }
        return nil
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
