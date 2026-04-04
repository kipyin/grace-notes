import CoreGraphics

/// Vertical space for the feathered calendar peek (issue #197). Sheets compute `remainingHeight` from layout;
/// only this region scrolls.
enum ReviewHistoryDrilldownPeekMetrics {
    /// Reference height from issue #186 (~1.5 months on compact widths). Not an upper cap: tall devices use
    /// extra space so the calendar is not artificially short.
    static var preferredViewportHeight: CGFloat {
        ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
    }

    /// Enough for ~2 week rows + banners at default Dynamic Type on narrow phones.
    static let minimumViewportHeight: CGFloat = 200

    static func clampedViewportHeight(remainingHeight: CGFloat) -> CGFloat {
        max(minimumViewportHeight, remainingHeight)
    }
}
