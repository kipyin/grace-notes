import CoreGraphics

/// Vertical space for the feathered calendar peek (issue #197). Sheets compute `remainingHeight` from layout;
/// only this region scrolls.
enum ReviewHistoryDrilldownPeekMetrics {
    /// Reference height from issue #186 (~1.5 months on compact widths). Not an upper cap: tall devices use
    /// extra space so the calendar is not artificially short.
    static var preferredViewportHeight: CGFloat {
        ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
    }

    /// Reference target when measuring layout; not a hard floor in ``clampedViewportHeight(remainingHeight:)`` —
    /// if geometry reports less space, the peek must not exceed that space (avoids overflow/clipping).
    static let minimumViewportHeight: CGFloat = 200

    /// Peek height matches laid-out remaining height (non-negative). When space is tight, returns the actual
    /// available height instead of inflating to ``minimumViewportHeight``, which would exceed the container.
    static func clampedViewportHeight(remainingHeight: CGFloat) -> CGFloat {
        max(0, remainingHeight)
    }
}
