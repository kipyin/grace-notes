import XCTest
@testable import GraceNotes

final class ShareTypographyScriptTests: XCTestCase {
    private let english = Locale.Language(identifier: "en")

    func test_current_englishUIBeforeJapaneseSystem_checksOnlyFirstBundleLocalization() {
        // Active UI is English (`preferredLocalizations.first`), system is Japanese: CJK should come
        // from the system locale, not from secondary entries in `preferredLocalizations`.
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "en",
            systemLanguage: Locale.Language(identifier: "ja")
        )
        XCTAssertEqual(script, .cjk)
    }

    func test_current_englishUIAndEnglishSystem_staysLatin_notCJKFromSecondaryPreferences() {
        // Regression: the full `preferredLocalizations` array can list additional user languages.
        // We must not treat a non-first entry (e.g. Japanese later in the list) as the app UI language.
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "en",
            systemLanguage: Locale.Language(identifier: "en")
        )
        XCTAssertEqual(script, .latin)
    }

    func test_current_usesPreferredUILocalizationIdentifier_zhHans_beforeSystemEnglish() {
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "zh-Hans",
            systemLanguage: english
        )
        XCTAssertEqual(script, .cjk)
    }

    func test_current_usesPreferredUILocalizationIdentifier_zhHant_beforeSystemEnglish() {
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "zh-Hant",
            systemLanguage: english
        )
        XCTAssertEqual(script, .cjk)
    }

    func test_current_usesPreferredUILocalizationIdentifier_ja_beforeSystemEnglish() {
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "ja",
            systemLanguage: english
        )
        XCTAssertEqual(script, .cjk)
    }

    func test_current_usesPreferredUILocalizationIdentifier_ko_beforeSystemEnglish() {
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "ko",
            systemLanguage: english
        )
        XCTAssertEqual(script, .cjk)
    }

    func test_current_fallsBackToSystemLanguage_whenUIIsEnglish() {
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "en",
            systemLanguage: Locale.Language(identifier: "zh-Hans")
        )
        XCTAssertEqual(script, .cjk)
    }

    func test_current_latinWhenUIAndSystemAreNonCJK() {
        let script = ShareTypographyScript.current(
            preferredUILocalizationIdentifier: "en",
            systemLanguage: english
        )
        XCTAssertEqual(script, .latin)
    }
}
