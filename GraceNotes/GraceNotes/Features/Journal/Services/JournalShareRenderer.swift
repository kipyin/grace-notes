import SwiftUI
import UIKit

enum JournalShareRenderer {
    /// Renders the share card to a bitmap.
    ///
    /// `ImageRenderer` proposes a size to the root view. If that size is effectively unbounded,
    /// flexible-width SwiftUI content can lay out poorly and `uiImage` may be nil or empty.
    /// A concrete width matches typical phone layout and keeps the export stable across devices.
    @MainActor static func renderImage(from payload: ShareRenderPayload) -> UIImage? {
        let cardView = JournalShareCardView(payload: payload, onLineTap: nil)
        let renderer = ImageRenderer(content: cardView)
        renderer.proposedSize = ProposedViewSize(width: Self.proposedLayoutWidth, height: nil)
        renderer.scale = Self.pixelScale
        return renderer.uiImage
    }

    private static let proposedLayoutWidth: CGFloat = 390

    private static var pixelScale: CGFloat {
        if #available(iOS 17.0, *) {
            return UITraitCollection.current.displayScale
        }
        return UIScreen.main.scale
    }
}
