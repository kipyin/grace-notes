import UIKit

/// Names the alternate app icon set in the asset catalog (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`).
@MainActor
enum AppAlternateIconSelection {
    /// Matches `AppIconLegacy.appiconset` and the generated `CFBundleAlternateIcons` entry.
    static let legacyAssetCatalogName = "AppIconLegacy"

    enum Choice: String, CaseIterable, Identifiable {
        case liquidGlass
        case legacy

        var id: String { rawValue }
    }

    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static func currentChoice() -> Choice {
        if UIApplication.shared.alternateIconName == legacyAssetCatalogName {
            return .legacy
        }
        return .liquidGlass
    }

    /// The system confirmation sheet and its icon preview are controlled by iOS; they may follow device
    /// appearance rather than Home Screen icon customization. There is no public API to change that preview.
    static func setChoice(_ choice: Choice, completion: @escaping (Error?) -> Void) {
        let name: String? = choice == .legacy ? legacyAssetCatalogName : nil
        UIApplication.shared.setAlternateIconName(name, completionHandler: completion)
    }
}

extension AppAlternateIconSelection.Choice {
    var localizedTitle: String {
        switch self {
        case .liquidGlass:
            return String(localized: "settings.advanced.appIcon.option.liquidGlass")
        case .legacy:
            return String(localized: "settings.advanced.appIcon.option.legacy")
        }
    }

    /// Asset catalog image name for Settings list preview (regular imageset, not appiconset).
    var settingsPreviewAssetName: String {
        switch self {
        case .liquidGlass:
            return "SettingsAppIconPreviewLiquidGlass"
        case .legacy:
            return "SettingsAppIconPreviewLegacy"
        }
    }
}
