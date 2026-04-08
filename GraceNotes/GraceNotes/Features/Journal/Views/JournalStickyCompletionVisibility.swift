import CoreGraphics

enum JournalStickyCompletionVisibility {
    /// Whether the journal body has scrolled enough that the completion header may leave the visible area.
    ///
    /// Global header frame vs safe area was unreliable at rest: the header often sits above
    /// `safeAreaTop + small slack` while still fully on-screen (large title, varied layouts), which kept the
    /// bar chip visible constantly. Scroll content `minY` in ``journalMainScroll`` decreases as the user
    /// scrolls down, which tracks “pulled the completion block upward” without depending on key-window reads.
    ///
    /// - Parameters:
    ///   - scrollContentMinY: Main journal column’s minY in the scroll view’s named coordinate space.
    ///   - scrollRevealThreshold: Show the chip when `scrollContentMinY` is below `-scrollRevealThreshold`.
    static func shouldShowBarIndicator(scrollContentMinY: CGFloat, scrollRevealThreshold: CGFloat) -> Bool {
        scrollContentMinY < -scrollRevealThreshold
    }
}
