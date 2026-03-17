import SwiftUI
import UIKit

enum JournalShareRenderer {
    @MainActor static func renderImage(from payload: JournalExportPayload) -> UIImage? {
        let cardView = JournalShareCardView(payload: payload)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
