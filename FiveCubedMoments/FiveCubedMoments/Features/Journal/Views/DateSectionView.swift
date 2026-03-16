import SwiftUI

/// Displays the journal entry date and completion status.
struct DateSectionView: View {
    let entryDate: Date
    let completedToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            HStack {
                Text(entryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                if completedToday {
                    Label("Completed for today", systemImage: "checkmark.circle.fill")
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.complete)
                } else {
                    Label("In progress", systemImage: "pencil.circle")
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
    }
}
