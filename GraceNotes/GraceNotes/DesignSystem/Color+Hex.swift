import SwiftUI

extension Color {
    /// 24-bit `RRGGBB`. High bits are masked so `AARRGGBB`-style literals still resolve to the same sRGB triplet.
    init(hex: UInt) {
        let rgb = hex & 0xFFFFFF
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue)
    }
}
