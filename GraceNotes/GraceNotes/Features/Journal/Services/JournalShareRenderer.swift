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

    private static var pixelScale: CGFloat {
        let scale = UITraitCollection.current.displayScale
        return scale > 0 ? scale : UIScreen.main.scale
    }
}
