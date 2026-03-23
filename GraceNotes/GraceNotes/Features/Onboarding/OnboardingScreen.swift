import SwiftUI

struct OnboardingScreen: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSection) {
            Spacer(minLength: AppTheme.spacingWide)

            Text(String(localized: "Welcome to Grace Notes"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                Text(String(localized: "We'll guide your first entry on Today—one quiet step at a time."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "Start with one gratitude, and the rest will follow."))
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.accentText)
            }
            .padding(AppTheme.spacingWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.journalInputBorder, lineWidth: 1)
            )

            Button(action: onGetStarted) {
                Text(String(localized: "Begin today's entry"))
                    .font(AppTheme.warmPaperBody.weight(.semibold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingRegular)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(WarmPaperPressStyle())
            .accessibilityHint(String(localized: "Opens Today and starts the guided first entry."))

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingWide)
        .padding(.vertical, AppTheme.spacingSection)
        .background(AppTheme.background.ignoresSafeArea())
    }
}
