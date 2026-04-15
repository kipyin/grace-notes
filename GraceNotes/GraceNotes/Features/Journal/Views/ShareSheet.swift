import SwiftUI
import UIKit

/// Wraps an image for sheet(item:); sheet presents only when non-nil, so content is guaranteed available.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Popover anchoring

private enum ShareSheetPopover {
    /// On iPad and other horizontally regular layouts, `UIActivityViewController` uses a popover and must have a
    /// valid popover source or the system can fail to present it.
    static func configureIfNeeded(for controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        guard let view = controller.viewIfLoaded else { return }
        guard view.bounds.width > 0, view.bounds.height > 0 else { return }

        popover.sourceView = view
        popover.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 0,
            height: 0
        )
        popover.permittedArrowDirections = []
    }
}

/// Defers popover configuration until the activity view is in the hierarchy and laid out, avoiding reliance on a
/// key window during the first `makeUIViewController` frame.
private final class ShareActivityViewController: UIActivityViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ShareSheetPopover.configureIfNeeded(for: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ShareSheetPopover.configureIfNeeded(for: self)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        precondition(!activityItems.isEmpty, "ShareSheet requires at least one activity item.")
        let controller = ShareActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        ShareSheetPopover.configureIfNeeded(for: controller)
        DispatchQueue.main.async {
            ShareSheetPopover.configureIfNeeded(for: controller)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        ShareSheetPopover.configureIfNeeded(for: uiViewController)
    }
}
