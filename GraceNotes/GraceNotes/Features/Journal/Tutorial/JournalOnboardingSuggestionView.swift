import SwiftUI

struct JournalOnboardingSuggestionView: View {
    let title: String
    let message: String
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                Text(title)
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.accentText)

                Text(message)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.journalTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: AppTheme.spacingRegular) {
                Button(action: onPrimaryAction) {
                    Text(primaryActionTitle)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .foregroundStyle(AppTheme.onAccent)

                Button(action: onSecondaryAction) {
                    Text(secondaryActionTitle)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accentText)
                .foregroundStyle(AppTheme.accentText)
            }
            .font(AppTheme.warmPaperBody)
        }
        .padding(AppTheme.spacingRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.journalPaper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.journalInputBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
