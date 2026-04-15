import XCTest
@testable import GraceNotes

final class AppInstructionLocaleTests: XCTestCase {
    func test_resolved_matchesRepresentativeBundlePreferredLocalizationTags() {
        let cases: [(String, AppInstructionLocale)] = [
            ("zh-Hans", .simplifiedChinese),
            ("zh_CN", .simplifiedChinese),
            ("zh_Hans_CN", .simplifiedChinese),
            ("zh", .simplifiedChinese),
            ("zh-Hant", .english),
            ("en", .english)
        ]
        for (tag, expected) in cases {
            XCTAssertEqual(
                AppInstructionLocale.resolved(forPreferredLocalizationIdentifier: tag),
                expected,
                "preferred localization tag: \(tag)"
            )
        }
    }

    func test_preferred_emptyPreferredLocalizations_fallsBackToEnglish() {
        let bundle = EmptyPreferredLocalizationsBundle()
        XCTAssertEqual(AppInstructionLocale.preferred(bundle: bundle), .english)
    }
}

private final class EmptyPreferredLocalizationsBundle: Bundle {
    init() {
        super.init(path: Bundle(for: EmptyPreferredLocalizationsBundle.self).bundlePath)!
    }

    override var preferredLocalizations: [String] { [] }
}
