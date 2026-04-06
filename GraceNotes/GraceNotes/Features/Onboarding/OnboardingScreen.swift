import SwiftUI

struct OnboardingScreen: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSection) {
            Spacer(minLength: AppTheme.spacingWide)

            Text(String(localized: "onboarding.welcome.title"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)

            VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                Text(String(localized: "onboarding.tagline"))
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.reminderSecondaryActionTint)
            }
            .padding(AppTheme.spacingWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.settingsPaper)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.journalInputBorder, lineWidth: 1)
            )

            Button(action: onGetStarted) {
                Text(String(localized: "onboarding.beginToday"))
                    .font(AppTheme.warmPaperBody.weight(.semibold))
                    .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingRegular)
                    .background(AppTheme.reminderPrimaryActionBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(WarmPaperPressStyle())
            .accessibilityHint(String(localized: "onboarding.beginEntryAccessibilityHint"))

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacingWide)
        .padding(.vertical, AppTheme.spacingSection)
        .background(AppTheme.settingsBackground.ignoresSafeArea())
    }
}
