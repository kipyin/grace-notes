import SwiftUI
import XCTest
@testable import GraceNotes

final class JournalKeyboardScrollCoordinatorTests: XCTestCase {
    func test_scrollAnchor_focusChanged_sentenceChips_usesCenter() {
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.peopleInputArea),
                scrollTarget: .peopleInputArea
            ),
            UnitPoint.center
        )
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.needInputArea),
                scrollTarget: .needInputArea
            ),
            UnitPoint.center
        )
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.gratitudeSection),
                scrollTarget: .gratitudeSection
            ),
            UnitPoint.center
        )
    }

    func test_scrollAnchor_focusChanged_notes_usesBottom() {
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .focusChanged(.readingNotes),
                scrollTarget: .readingNotes
            ),
            UnitPoint.bottom
        )
    }

    func test_scrollAnchor_typing_usesBottom() {
        XCTAssertEqual(
            JournalKeyboardScrollCoordinator.scrollAnchor(
                for: .typing(.peopleInputArea),
                scrollTarget: .peopleInputArea
            ),
            UnitPoint.bottom
        )
    }
}
