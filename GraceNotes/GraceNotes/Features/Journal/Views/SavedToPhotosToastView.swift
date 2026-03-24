import SwiftUI

/// Toast shown when the user saves the share image to Photos.
struct SavedToPhotosToastView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.journalComplete)
            Text(String(localized: "Saved to Photos"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.journalTextPrimary)
        }
        .padding(.horizontal, AppTheme.spacingWide)
        .padding(.vertical, AppTheme.spacingRegular)
        .background(AppTheme.journalPaper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.journalBorder, lineWidth: 1)
        )
        .journalToastOuterGlow(accentColor: AppTheme.journalComplete, reduceTransparency: reduceTransparency)
        .padding(.bottom, 32)
    }
}
