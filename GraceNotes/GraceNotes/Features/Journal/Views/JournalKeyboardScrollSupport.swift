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
