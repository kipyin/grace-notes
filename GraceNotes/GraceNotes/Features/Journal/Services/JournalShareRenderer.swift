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
    /// Use the same width as the fixed export card plus its horizontal padding so the bitmap matches
    /// the composer export layout and is not clipped.
    @MainActor static func renderImage(from payload: ShareRenderPayload) -> UIImage? {
        let cardView = JournalShareCardView(payload: payload, onLineTap: nil)
        let renderer = ImageRenderer(content: cardView)
        renderer.proposedSize = ProposedViewSize(width: JournalShareExportMetrics.totalLayoutWidth, height: nil)
        renderer.scale = Self.pixelScale
        return renderer.uiImage
    }

    private static var pixelScale: CGFloat {
        let screenScale = UIScreen.main.scale

        if #available(iOS 17.0, *) {
            let traitScale = UITraitCollection.current.displayScale
            if traitScale > 0 {
                return traitScale
            }
        }

        return screenScale > 0 ? screenScale : 1
    }
}
