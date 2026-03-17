import SwiftUI

/// Displays the journal entry date and completion status.
struct DateSectionView: View {
    let entryDate: Date
    let completionLevel: JournalCompletionLevel
    let streakSummary: StreakSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            HStack {
                Text(entryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                completionStatusLabel
            }

            HStack(spacing: 12) {
                Label(
                    String(
                        format: String(localized: "Basic %lld"),
                        locale: .current,
                        Int64(streakSummary.basicCurrent)
                    ),
                    systemImage: "flame"
                )
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(streakSummary.basicDoneToday ? AppTheme.complete : AppTheme.textMuted)
                Label(
                    String(
                        format: String(localized: "Perfect %lld"),
                        locale: .current,
                        Int64(streakSummary.perfectCurrent)
                    ),
                    systemImage: "star.fill"
                )
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(streakSummary.perfectDoneToday ? AppTheme.complete : AppTheme.textMuted)
            }
        }
    }

    @ViewBuilder
    private var completionStatusLabel: some View {
        switch completionLevel {
        case .fullFiveCubed:
            Label("Full 5³ complete", systemImage: "checkmark.circle.fill")
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.complete)
        case .standardReflection:
            Label("Standard reflection", systemImage: "checkmark.seal.fill")
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.accent)
        case .quickCheckIn:
            Label("Quick check-in", systemImage: "sparkles")
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
        case .none:
            Label("In progress", systemImage: "pencil.circle")
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
        }
    }
}
