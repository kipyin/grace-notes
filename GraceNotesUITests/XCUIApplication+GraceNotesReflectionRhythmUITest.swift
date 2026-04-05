import XCTest

extension XCUIApplication {
    /// Title of the Past tab reflection rhythm panel. Catalog key is `Reflection rhythm`; English is “Days you wrote”.
    /// The title is drilldown chrome (a `Button`), not a separate `StaticText`, so `staticTexts["…"]` queries miss it.
    var graceNotesReflectionRhythmTitle: XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Days you wrote")).firstMatch
    }

    /// Same label after insights **finish**: skeleton title is `StaticText`, live title is tappable `Button`.
    /// Use this—not ``graceNotesReflectionRhythmTitle``—before `ReviewRhythmHorizontalScroll` or rhythm columns.
    var graceNotesReflectionRhythmTitleReady: XCUIElement {
        buttons["Days you wrote"].firstMatch
    }
}
