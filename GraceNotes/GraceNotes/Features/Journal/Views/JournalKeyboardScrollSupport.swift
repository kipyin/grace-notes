import SwiftUI
import UIKit

/// Stable `ScrollViewReader` targets for Today journal keyboard avoidance.
enum JournalScrollTarget: String, CaseIterable {
    case sentenceSections
    case readingNotes
    case reflections
}

/// Hybrid margin: scales with body line height (Dynamic Type) with a floor so the gap never collapses.
enum JournalKeyboardScrollMetrics {
    static func comfortMarginAboveKeyboard() -> CGFloat {
        let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
        let scaled = lineHeight + AppTheme.spacingTight
        return max(AppTheme.spacingRegular, scaled)
    }
}

/// Keyboard overlap with the key window; sizes extra scroll affordance without guessing global safe-area behavior.
enum JournalKeyboardOverlapReader {
    static func overlapHeight(from notification: Notification) -> CGFloat {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else {
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
