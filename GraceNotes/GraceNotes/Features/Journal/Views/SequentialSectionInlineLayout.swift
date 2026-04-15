import UIKit

/// Shared metrics for inline sentence editing (entry-row editor and add morph composer).
///
/// Layout spacing uses `UIFontMetrics(forTextStyle: .body)` because
/// `InlineSentenceEditorField` applies body Dynamic Type scaling to its `UITextView`
/// (`InlineSentenceEditorFieldLayout.bodyUIFont()`), so inset, offset, and bottom
/// spacing follow the same curve as the editor typography.
enum SequentialSectionInlineLayout {
    private static let bodyMetrics = UIFontMetrics(forTextStyle: .body)

    static var editorMorphHorizontalInset: CGFloat {
        bodyMetrics.scaledValue(for: 6)
    }

    static var editorMorphVerticalOffset: CGFloat {
        bodyMetrics.scaledValue(for: 8)
    }

    static var editorBottomSpacing: CGFloat {
        bodyMetrics.scaledValue(for: 10)
    }

    /// Opacity for non-focused rows and guidance while inline editing is active elsewhere in the journal.
    static let ambientUnfocusedOpacity: CGFloat = 0.45

    private static let inlineEditBottomTapCatcherBasePoints: CGFloat = 280
    /// Upper bound as a fraction of screen height (avoids huge empty scroll at accessibility sizes).
    private static let bottomTapCatcherScreenHeightCap: CGFloat = 0.42

    /// Minimum height for bottom tap catcher when journal content is short (dismiss inline edit from empty space).
    static var inlineEditBottomTapCatcherMinHeight: CGFloat {
        let scaled = bodyMetrics.scaledValue(for: inlineEditBottomTapCatcherBasePoints)
        let screenCap = UIScreen.main.bounds.height * bottomTapCatcherScreenHeightCap
        return min(scaled, screenCap)
    }
}
