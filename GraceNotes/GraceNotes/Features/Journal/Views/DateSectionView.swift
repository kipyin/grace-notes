import SwiftUI

/// Displays the journal entry date and completion status.
struct DateSectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let entryDate: Date
    let completionLevel: JournalCompletionLevel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text("Date")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                    dateLabel
                    completionStatusLabel
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.spacingTight) {
                        dateLabel
                        completionStatusLabel
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                        dateLabel
                        completionStatusLabel
                    }
                }
            }
        }
    }

    private var dateLabel: some View {
        Text(entryDate.formatted(date: .abbreviated, time: .omitted))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)
            .monospacedDigit()
    }

    private var completionStatusLabel: some View {
        Group {
            switch completionLevel {
            case .fullFiveCubed:
                Label("Full 5³ complete", systemImage: "checkmark.circle.fill")
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.completeText)
            case .standardReflection:
                Label("Standard reflection", systemImage: "checkmark.seal.fill")
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.accent)
            case .quickCheckIn:
                Label("Quick check-in", systemImage: "sparkles")
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.textMuted)
            case .none:
                Label("In progress", systemImage: "pencil.circle")
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
    }
}
