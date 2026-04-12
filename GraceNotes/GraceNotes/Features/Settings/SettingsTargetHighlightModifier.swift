import SwiftUI

struct SettingsTargetHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(isHighlighted ? AppTheme.spacingTight : 0)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(AppTheme.journalPaper.opacity(0.82))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .strokeBorder(AppTheme.accent, lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func settingsTargetHighlight(_ isHighlighted: Bool) -> some View {
        modifier(SettingsTargetHighlightModifier(isHighlighted: isHighlighted))
    }
}
