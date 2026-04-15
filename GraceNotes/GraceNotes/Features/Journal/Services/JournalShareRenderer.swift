import SwiftUI
import UIKit

/// Layout metrics for fixed-width share export (`JournalShareCardView` with `usesFixedExportWidth == true`)
/// and bitmap rendering (`JournalShareRenderer`). Keeps `ImageRenderer`'s proposed width aligned with the card.
enum JournalShareExportMetrics {
    static let cardContentWidth: CGFloat = 448
    static let horizontalPadding: CGFloat = 24
    /// Card column width plus horizontal padding (matches `JournalShareCardView` fixed export layout).
    static var totalLayoutWidth: CGFloat { cardContentWidth + horizontalPadding * 2 }
}

enum JournalShareRenderer {
    /// Renders the share card to a bitmap.
    ///
    /// `ImageRenderer` proposes a size to the root view. If that size is effectively unbounded,
    /// flexible-width SwiftUI content can lay out poorly and `uiImage` may be nil or empty.
    /// Width matches the fixed export card plus horizontal padding via `JournalShareExportMetrics`.
    @MainActor static func renderImage(from payload: ShareRenderPayload) -> UIImage? {
        let cardView = JournalShareCardView(payload: payload, onLineTap: nil)
        let renderer = ImageRenderer(content: cardView)
        renderer.proposedSize = ProposedViewSize(width: JournalShareExportMetrics.totalLayoutWidth, height: nil)
        renderer.scale = Self.recommendedPixelScale()
        guard let image = renderer.uiImage else { return nil }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        guard let cgImage = image.cgImage else { return nil }
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }
        return image
    }

    /// `ImageRenderer` runs without hosting in a window; `UITraitCollection.current.displayScale` can be
    /// unset or 1× while the device screen is Retina. Uses the highest positive scale available from any
    /// foreground window scene (active or inactive — a presented sheet can leave the root scene inactive),
    /// the current trait collection, or the main screen, then clamps to a safe supported range. Ignores
    /// background/unattached scenes so multi-window layouts do not pick an unrelated display’s scale.
    @MainActor
    private static func recommendedPixelScale() -> CGFloat {
        let traitScale = UITraitCollection.current.displayScale
        // Deliberately take the maximum across foreground scenes so export matches the sharpest attached
        // screen when multiple windows are visible.
        let sceneScale = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter {
                $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
            }
            .map { $0.screen.scale }
            .max() ?? 0
        let screenScale = UIScreen.main.scale
        let best = max(
            traitScale > 0 ? traitScale : 0,
            sceneScale > 0 ? sceneScale : 0,
            screenScale > 0 ? screenScale : 0
        )
        return best > 0 ? best : 3
    }
}
