import SwiftUI

struct JournalOnboardingSuggestionView: View {
    @Environment(\.todayJournalPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons
                .font(AppTheme.warmPaperBody)
        }
        .padding(AppTheme.spacingRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paper.opacity(palette.sectionPaperOpacity))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(palette.inputBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppTheme.spacingRegular) {
                primaryActionButton
                secondaryActionButton
            }
        } else {
            HStack(spacing: AppTheme.spacingRegular) {
                primaryActionButton
                secondaryActionButton
            }
        }
    }

    private var primaryActionButton: some View {
        Button(action: onPrimaryAction) {
            Text(primaryActionTitle)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
        .foregroundStyle(AppTheme.onAccent)
    }

    private var secondaryActionButton: some View {
        Button(action: onSecondaryAction) {
            Text(secondaryActionTitle)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.accentText)
        .foregroundStyle(AppTheme.accentText)
    }
}
