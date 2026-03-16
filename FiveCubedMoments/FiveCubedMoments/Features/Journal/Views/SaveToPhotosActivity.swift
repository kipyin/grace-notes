import Foundation
import Photos
import UIKit

extension Notification.Name {
    static let photoSavedToLibrary = Notification.Name("photoSavedToLibrary")
}

/// Custom UIActivity that saves an image to the photo library.
/// Requires NSPhotoLibraryAddUsageDescription in Info.plist.
final class SaveToPhotosActivity: UIActivity {
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.fivecubedmoments.SaveToPhotos")
    }

    override var activityTitle: String? {
        "Save to Photos"
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "photo.on.rectangle.angled")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is UIImage }
    }

    override func perform() {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: self.image)
        } completionHandler: { [weak self] success, _ in
            DispatchQueue.main.async {
                if success {
                    NotificationCenter.default.post(name: .photoSavedToLibrary, object: nil)
                }
                self?.activityDidFinish(success)
            }
        }
    }
}
