import UIKit
import XCTest
@testable import GraceNotes

final class SaveToPhotosActivityTests: XCTestCase {
    func test_canPerform_trueWhenActivityItemsIncludeImage() {
        let activity = SaveToPhotosActivity(image: UIImage())

        XCTAssertTrue(activity.canPerform(withActivityItems: [UIImage()]))
    }

    func test_canPerform_falseWhenNoImage() {
        let activity = SaveToPhotosActivity(image: UIImage())

        XCTAssertFalse(activity.canPerform(withActivityItems: ["text only"]))
    }

    func test_activityMetadata_forShareSheetIdentity() {
        let activity = SaveToPhotosActivity(image: UIImage())

        XCTAssertNotNil(activity.activityType)
        XCTAssertEqual(activity.activityTitle, String(localized: "sharing.saveToPhotos"))
    }
}
