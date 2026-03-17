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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.bottom, 32)
    }
}
