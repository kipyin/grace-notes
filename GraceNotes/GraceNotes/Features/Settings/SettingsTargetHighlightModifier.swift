import SwiftUI

struct SettingsTargetHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(isHighlighted ? AppTheme.spacingTight : 0)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(AppTheme.journalPaper.opacity(reduceTransparency ? 1.0 : 0.82))
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
            .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}

extension View {
    func settingsTargetHighlight(_ isHighlighted: Bool) -> some View {
        modifier(SettingsTargetHighlightModifier(isHighlighted: isHighlighted))
    }
}
