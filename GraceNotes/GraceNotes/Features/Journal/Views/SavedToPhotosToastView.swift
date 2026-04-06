import SwiftUI

/// Toast shown when the user saves the share image to Photos.
struct SavedToPhotosToastView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.todayJournalPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.complete)
            Text(String(localized: "sharing.savedToPhotos"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(palette.textPrimary)
        }
        .padding(.horizontal, AppTheme.spacingWide)
        .padding(.vertical, AppTheme.spacingRegular)
        .background(
            reduceTransparency
                ? palette.paper
                : palette.paper.opacity(palette.sectionPaperOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(palette.border, lineWidth: 1)
        )
        .journalToastOuterGlow(accentColor: palette.complete, reduceTransparency: reduceTransparency)
        .padding(.bottom, 32)
    }
}
