import CoreGraphics

/// Vertical space for the feathered calendar peek (issue #197). Sheets compute `remainingHeight` from layout;
/// only this region scrolls.
enum ReviewHistoryDrilldownPeekMetrics {
    /// Matches existing grid default from issue #186 (≈1.5 months visible).
    static var preferredViewportHeight: CGFloat {
        ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
    }

    /// Enough for ~2 week rows + banners at default Dynamic Type on narrow phones.
    static let minimumViewportHeight: CGFloat = 200

    static func clampedViewportHeight(remainingHeight: CGFloat) -> CGFloat {
        min(preferredViewportHeight, max(minimumViewportHeight, remainingHeight))
    }
}
