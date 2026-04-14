import SwiftUI
import UIKit

/// Wraps an image for sheet(item:); sheet presents only when non-nil, so content is guaranteed available.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        assert(!activityItems.isEmpty, "ShareSheet requires at least one activity item.")
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        configurePopoverPresentationIfNeeded(for: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    /// On iPad and other horizontally regular layouts, `UIActivityViewController` uses a popover and must have a
    /// valid popover source or the system can fail to present it.
    private func configurePopoverPresentationIfNeeded(for controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else { return }

        popover.sourceView = window
        popover.sourceRect = CGRect(
            x: window.bounds.midX,
            y: window.bounds.midY,
            width: 0,
            height: 0
        )
        popover.permittedArrowDirections = []
    }
}
