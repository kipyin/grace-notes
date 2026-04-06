import SwiftUI
import UIKit

enum JournalShareRenderer {
    @MainActor static func renderImage(from payload: ShareRenderPayload) -> UIImage? {
        let cardView = JournalShareCardView(payload: payload, onLineTap: nil)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
