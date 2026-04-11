import SwiftUI

// MARK: - Loading primitives

/// Soft, static bars — motion (if any) comes from ``InsightsCalmLoadingBreath`` on the whole skeleton.
struct InsightsPlaceholderBar: View {
    var widthFraction: CGFloat = 1.0
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let fraction = min(1, max(0, widthFraction))
            let lineWidth = max(geo.size.width * fraction, height * 2)
            RoundedRectangle(cornerRadius: height * 0.42, style: .continuous)
                .fill(AppTheme.reviewTextMuted.opacity(0.10))
                .frame(width: lineWidth, height: height, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Very slow, low-contrast breathing — no traveling highlight.
struct InsightsCalmLoadingBreath: ViewModifier {
    let active: Bool
    private var period: Double { 5.5 }
    private var opacitySwing: Double { 0.028 }

    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(minimumInterval: 0.4, paused: false)) { context in
                let seconds = context.date.timeIntervalSinceReferenceDate
                let wave = sin(seconds * 2 * .pi / period)
                let opacity = 0.965 + opacitySwing * wave
                content.opacity(opacity)
            }
        } else {
            content.opacity(0.97)
        }
    }
}

func reviewInsightSanitizedThemeId(_ value: String) -> String {
    // POSIX keeps accessibility identifiers stable across user locales (e.g. Turkish casing rules).
    let stableLocale = Locale(identifier: "en_US_POSIX")
    let cleaned = value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: stableLocale)
        .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    if cleaned.isEmpty {
        return "theme"
    }
    return cleaned
}
