import Foundation

/// Shared metrics for inline sentence editing (entry-row editor and add morph composer).
enum SequentialSectionInlineLayout {
    static let editorMorphHorizontalInset: CGFloat = 6
    static let editorMorphVerticalOffset: CGFloat = 8
    static let editorBottomSpacing: CGFloat = 10
    /// Opacity for non-focused rows and guidance while inline editing is active elsewhere in the journal.
    static let ambientUnfocusedOpacity: CGFloat = 0.45
    /// Minimum height for bottom tap catcher when journal content is short (dismiss inline edit from empty space).
    static let inlineEditBottomTapCatcherMinHeight: CGFloat = 280
}
