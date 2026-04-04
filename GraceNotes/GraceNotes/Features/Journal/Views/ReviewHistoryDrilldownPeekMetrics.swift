import CoreGraphics

/// Peek height helper for the feathered calendar (issue #197). Callers compute `remainingHeight` from layout;
/// this type does not re-apply min/preferred caps so the grid never exceeds geometry.
enum ReviewHistoryDrilldownPeekMetrics {
    /// Reference height from issue #186 (~1.5 months on compact widths). Used in tests and docs; not applied
    /// inside ``clampedViewportHeight(remainingHeight:)``.
    static var preferredViewportHeight: CGFloat {
        ReviewHistoryDrilldownCalendarGrid.Metrics.scrollViewportHeight
    }

    /// Notional comfortable minimum height (tests / product reference only). Tight layouts use a smaller
    /// ``clampedViewportHeight`` rather than inflating past ``remainingHeight``.
    static let minimumViewportHeight: CGFloat = 200

    /// Uses at most the non-negative space remaining; never inflates above `remainingHeight`.
    static func clampedViewportHeight(remainingHeight: CGFloat) -> CGFloat {
        max(0, remainingHeight)
    }
}
