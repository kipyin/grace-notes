import SwiftUI

/// Toast shown when the user saves the share image to Photos.
struct SavedToPhotosToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.complete)
            Text(String(localized: "Saved to Photos"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, AppTheme.spacingWide)
        .padding(.vertical, AppTheme.spacingRegular)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.bottom, 32)
    }
}
