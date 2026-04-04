import SwiftUI

// MARK: - Sheet stack depth (nested SwiftUI sheets)

private struct AppSheetStackDepthKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// Depth of nested SwiftUI `sheet` presentations.
    /// Used by ``View/appTranslucentSheetChrome(fallbackSolid:)``.
    var appSheetStackDepth: Int {
        get { self[AppSheetStackDepthKey.self] }
        set { self[AppSheetStackDepthKey.self] = newValue }
    }
}

// MARK: - Translucent presentation

/// Standard presentation for modal sheets: material blur when transparency is allowed,
/// solid fallback for Reduce Transparency.
/// Nested sheets use a clear `presentationBackground` so only the outer layer blurs;
/// stacked sheets share one frosted backdrop.
private struct AppTranslucentSheetChrome: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.appSheetStackDepth) private var sheetStackDepth

    let fallbackSolid: Color

    func body(content: Content) -> some View {
        content
            .environment(\.appSheetStackDepth, sheetStackDepth + 1)
            .presentationBackground(sheetBackdrop)
            .toolbarBackground(toolbarBackdrop, for: .navigationBar)
    }

    private var sheetBackdrop: AnyShapeStyle {
        if reduceTransparency {
            AnyShapeStyle(fallbackSolid)
        } else if sheetStackDepth == 0 {
            AnyShapeStyle(Material.regularMaterial)
        } else {
            AnyShapeStyle(Color.clear)
        }
    }

    private var toolbarBackdrop: AnyShapeStyle {
        if reduceTransparency {
            AnyShapeStyle(fallbackSolid)
        } else if sheetStackDepth == 0 {
            AnyShapeStyle(Material.regularMaterial)
        } else {
            AnyShapeStyle(Color.clear)
        }
    }
}

extension View {
    /// Applies shared translucent sheet chrome: material behind content at the root of a sheet,
    /// clear for nested sheets, solid when Reduce Transparency is on.
    func appTranslucentSheetChrome(fallbackSolid: Color) -> some View {
        modifier(AppTranslucentSheetChrome(fallbackSolid: fallbackSolid))
    }
}
