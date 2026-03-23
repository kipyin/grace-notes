import SwiftUI

struct JournalOnboardingGuidanceView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text(title)
                .font(AppTheme.warmPaperMetaEmphasis)
                .foregroundStyle(AppTheme.accentText)

            Text(message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.journalTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacingRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.journalPaper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.journalInputBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
