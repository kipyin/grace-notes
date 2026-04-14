import CoreGraphics

/// Sticky completion chip visibility from scroll position.
///
/// Uses **Schmitt-style hysteresis** so a scroll offset sitting near the reveal threshold
/// (or tiny layout jitter there) does not flip the chip—and unlock feedback placement—rapidly.
enum JournalStickyCompletionVisibility {
    // MARK: - Hysteresis (points beyond `scrollRevealThreshold`)

    /// When hidden, the bar engages only after scroll passes this far past the threshold.
    private static let engagePadding: CGFloat = 12
    /// When shown, the bar releases only after scroll returns this close to the threshold.
    private static let releasePadding: CGFloat = 3

    // MARK: - iOS 18+ (scroll content offset)

    /// Reveal the toolbar chip when the user has scrolled the journal body down past `scrollRevealThreshold`.
    ///
    /// Uses the scroll view's ``ScrollGeometry/contentOffset`` ``y`` (larger when content moves up).
    ///
    /// - Parameter currentlyRevealed: Pass the **current** sticky state so hysteresis can apply.
    static func shouldShowBarIndicator(
        scrollContentOffsetY: CGFloat,
        scrollRevealThreshold: CGFloat,
        currentlyRevealed: Bool
    ) -> Bool {
        guard scrollContentOffsetY.isFinite, scrollRevealThreshold.isFinite else {
            return currentlyRevealed
        }
        if currentlyRevealed {
            return scrollContentOffsetY > scrollRevealThreshold + releasePadding
        }
        return scrollContentOffsetY > scrollRevealThreshold + engagePadding
    }

    // MARK: - iOS 17 (header frame in scroll space)

    /// Reveal the toolbar chip when the completion header's top edge in the scroll view's named coordinate
    /// space sits above the visible origin by more than `scrollRevealThreshold` (i.e. `minY < -threshold`).
    ///
    /// Global header frame vs safe area was unreliable at rest: the header often sits above
    /// `safeAreaTop + small slack` while still fully on-screen (large title, varied layouts), which kept the
    /// bar chip visible constantly. Scroll-space `minY` decreases as the user scrolls down, which tracks
    /// “pulled the completion block upward” without depending on key-window reads.
    ///
    /// - Parameter currentlyRevealed: Pass the **current** sticky state so hysteresis can apply.
    static func shouldShowBarIndicator(
        headerMinYInScrollSpace: CGFloat,
        scrollRevealThreshold: CGFloat,
        currentlyRevealed: Bool
    ) -> Bool {
        guard headerMinYInScrollSpace.isFinite, scrollRevealThreshold.isFinite else {
            return currentlyRevealed
        }
        if currentlyRevealed {
            return headerMinYInScrollSpace < -(scrollRevealThreshold + releasePadding)
        }
        return headerMinYInScrollSpace < -(scrollRevealThreshold + engagePadding)
    }
}
