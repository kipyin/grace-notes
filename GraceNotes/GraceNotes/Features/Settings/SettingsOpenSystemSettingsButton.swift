import SwiftUI

struct SettingsOpenSystemSettingsButton: View {
    let action: () -> Void
    let accessibilityHint: String

    var body: some View {
        Button(action: action) {
            Text(String(localized: "Open Settings"))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .font(AppTheme.warmPaperBody)
        .tint(AppTheme.reminderSecondaryActionTint)
        .foregroundStyle(AppTheme.reminderSecondaryActionTint)
        .accessibilityHint(accessibilityHint)
    }
}
