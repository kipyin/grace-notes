import UIKit

/// Shared metrics for inline sentence editing (entry-row editor and add morph composer).
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

    /// Minimum height for bottom tap catcher when journal content is short (dismiss inline edit from empty space).
    static var inlineEditBottomTapCatcherMinHeight: CGFloat {
        bodyMetrics.scaledValue(for: 280)
    }
}
