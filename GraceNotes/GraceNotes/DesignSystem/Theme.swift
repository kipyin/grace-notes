import SwiftUI

enum AppTheme {
    // MARK: - Colors

    static let background = Color(hex: 0xF8F4EF)
    static let paper = Color(hex: 0xF5EDE4)
    static let textPrimary = Color(hex: 0x2C2C2C)
    static let textMuted = Color(hex: 0x5C5346)
    static let accent = Color(hex: 0xC77B5B)
    static let complete = Color(hex: 0x8B9A7D)
    static let completeText = Color(hex: 0x5F6D54)
    static let error = Color(hex: 0xA3564A)
    static let border = Color(hex: 0xE5DDD4)

    /// Alias for accent; kept for backward compatibility.
    static let primaryColor = accent

    // MARK: - Typography

    static let warmPaperHeader = Font.custom("PlayfairDisplay-Regular", size: 22)
        .weight(.semibold)
    static let warmPaperBody = Font.custom("SourceSerif4Roman-Regular", size: 17)
    static let warmPaperMeta = Font.custom("SourceSerif4Roman-Regular", size: 15)
    static let warmPaperMetaEmphasis = Font.custom("SourceSerif4Roman-Regular", size: 15)
        .weight(.semibold)

    // MARK: - Spacing & Radius

    static let spacingTight: CGFloat = 8
    static let spacingRegular: CGFloat = 12
    static let spacingWide: CGFloat = 16
    static let spacingSection: CGFloat = 24
    static let floatingTabBarClearance: CGFloat = 84
    static let cornerRadiusMedium: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 16
}

// MARK: - Input Styling

/// Applies Warm Paper styling: rounded corners, light border, paper-tinted background.
/// System applies default focus styling when the input is focused.
struct WarmPaperInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.spacingRegular)
            .background(AppTheme.paper.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func warmPaperInputStyle() -> some View {
        modifier(WarmPaperInputStyle())
    }
}

/// Shared press feedback for tappable controls on warm paper surfaces.
struct WarmPaperPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Color Hex Extension

private extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
