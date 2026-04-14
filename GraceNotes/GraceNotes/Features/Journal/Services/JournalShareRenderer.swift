import SwiftUI
import UIKit

enum JournalShareRenderer {
    /// Renders the share card to a bitmap.
    ///
    /// `ImageRenderer` proposes a size to the root view. If that size is effectively unbounded,
    /// flexible-width SwiftUI content can lay out poorly and `uiImage` may be nil or empty.
    /// Width must match `JournalShareCardView` export layout: inner `cardWidth` plus horizontal `padding`.
    @MainActor static func renderImage(from payload: ShareRenderPayload) -> UIImage? {
        let cardView = JournalShareCardView(payload: payload, onLineTap: nil)
        let renderer = ImageRenderer(content: cardView)
        renderer.proposedSize = ProposedViewSize(width: Self.proposedLayoutWidth, height: nil)
        renderer.scale = Self.pixelScale
        guard let image = renderer.uiImage else { return nil }
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }

    /// Keep in sync with `JournalShareCardView` (`cardWidth` + twice `padding`).
    private static let proposedLayoutWidth: CGFloat = 448 + 24 * 2

    /// `ImageRenderer` runs without hosting in a window; `UITraitCollection.current.displayScale` can be
    /// unset or 1× while the device screen is Retina. Take the best positive value between trait and screen.
    private static var pixelScale: CGFloat {
        let traitScale = UITraitCollection.current.displayScale
        let screenScale = UIScreen.main.scale
        let best = max(traitScale > 0 ? traitScale : 0, screenScale > 0 ? screenScale : 0)
        return best > 0 ? best : 3
    }
}
