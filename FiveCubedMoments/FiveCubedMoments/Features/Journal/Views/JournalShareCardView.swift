import SwiftUI

struct JournalShareCardView: View {
    let payload: JournalExportPayload

    private static let cardWidth: CGFloat = 400
    private static let padding: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(payload.dateFormatted)
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            sectionIfNonEmpty(String(localized: "Gratitudes"), items: payload.gratitudes)
            sectionIfNonEmpty(String(localized: "Needs"), items: payload.needs)
            sectionIfNonEmpty(String(localized: "People in Mind"), items: payload.people)

            if !payload.readingNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Reading Notes"))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(payload.readingNotes)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !payload.reflections.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Reflections"))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(payload.reflections)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(width: JournalShareCardView.cardWidth)
        .padding(JournalShareCardView.padding)
        .background(AppTheme.paper)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func sectionIfNonEmpty(_ title: String, items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1). \(item)")
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
