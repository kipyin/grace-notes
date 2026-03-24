import SwiftUI

struct SettingsTargetHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, isHighlighted ? AppTheme.spacingTight : 0)
            .padding(.vertical, isHighlighted ? AppTheme.spacingTight : 0)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(AppTheme.journalPaper.opacity(0.82))
                }
            }
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.accent, lineWidth: 1)
                }
            }
    }
}

extension View {
    func settingsTargetHighlight(_ isHighlighted: Bool) -> some View {
        modifier(SettingsTargetHighlightModifier(isHighlighted: isHighlighted))
    }
}
