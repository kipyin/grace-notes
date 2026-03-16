import SwiftUI

enum AppTheme {
    // MARK: - Colors

    static let background = Color(hex: 0xF8F4EF)
    static let paper = Color(hex: 0xF5EDE4)
    static let textPrimary = Color(hex: 0x2C2C2C)
    static let textMuted = Color(hex: 0x5C5346)
    static let accent = Color(hex: 0xC77B5B)
    static let complete = Color(hex: 0x8B9A7D)
    static let border = Color(hex: 0xE5DDD4)

    /// Alias for accent; kept for backward compatibility.
    static let primaryColor = accent

    // MARK: - Typography

    static let warmPaperHeader = Font.custom("PlayfairDisplay-Regular", size: 22)
        .weight(.semibold)
    static let warmPaperBody = Font.custom("SourceSerif4Roman-Regular", size: 17)
}

// MARK: - Input Styling

/// Applies Warm Paper styling: rounded corners, light border, paper-tinted background.
/// System applies default focus styling when the input is focused.
struct WarmPaperInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(AppTheme.paper.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func warmPaperInputStyle() -> some View {
        modifier(WarmPaperInputStyle())
    }
}

// MARK: - Color Hex Extension

private extension Color {
    init(hex: UInt) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
