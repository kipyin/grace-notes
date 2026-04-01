import SwiftUI

private enum PastSearchListLayout {
    static var rowInsets: EdgeInsets {
        let inset = AppTheme.spacingWide
        return EdgeInsets(top: 2, leading: inset, bottom: 6, trailing: inset)
    }
}

enum PastJournalSearchGrouping {
    static func groups(
        matches: [JournalSearchMatch],
        calendar: Calendar
    ) -> [(day: Date, rows: [JournalSearchMatch])] {
        let grouped = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.entryDate) }
        return grouped.keys.sorted(by: >).map { day in
            let rows = (grouped[day] ?? []).sorted { lhs, rhs in
                if lhs.source != rhs.source {
                    return lhs.source.rawValue < rhs.source.rawValue
                }
                return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
            }
            return (day, rows)
        }
    }
}

struct PastJournalSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.reviewTextMuted)
            TextField(String(localized: "Search journal"), text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .accessibilityLabel(String(localized: "Search journal"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .fill(AppTheme.reviewPaper.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .strokeBorder(AppTheme.reviewStandardBorder.opacity(0.42), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .circular))
        .accessibilityElement(children: .combine)
    }
}

struct PastJournalSearchResultsList: View {
    let matches: [JournalSearchMatch]
    let calendar: Calendar

    private var groupedMatches: [(day: Date, rows: [JournalSearchMatch])] {
        PastJournalSearchGrouping.groups(matches: matches, calendar: calendar)
    }

    var body: some View {
        if matches.isEmpty {
            Section {
                ContentUnavailableView {
                    Label(String(localized: "No matches"), systemImage: "magnifyingglass")
                } description: {
                    Text(String(localized: "PastSearch.noMatches.description"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowInsets(PastSearchListLayout.rowInsets)
            .listRowBackground(AppTheme.reviewBackground)
            .listRowSeparator(.hidden)
        } else {
            Section {
                ForEach(groupedMatches, id: \.day) { group in
                    Section {
                        ForEach(group.rows) { match in
                            NavigationLink {
                                JournalScreen(entryDate: match.entryDate)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(match.source.localizedJournalSurfaceTitle)
                                        .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                                        .foregroundStyle(AppTheme.reviewTextPrimary)
                                    Text(match.content)
                                        .font(AppTheme.warmPaperBody)
                                        .foregroundStyle(AppTheme.reviewTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(rowAccessibilityLabel(day: group.day, match: match))
                            .accessibilityHint(String(localized: "ThemeDrilldown.openEntry.a11yHint"))
                            .listRowInsets(PastSearchListLayout.rowInsets)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text(group.day.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .textCase(nil)
                    }
                }
            } header: {
                Text(String(localized: "Matching writing surfaces"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                    .textCase(nil)
            }
        }
    }

    private func rowAccessibilityLabel(day: Date, match: JournalSearchMatch) -> String {
        let dayText = day.formatted(date: .abbreviated, time: .omitted)
        return [dayText, match.source.localizedJournalSurfaceTitle, match.content].joined(separator: ", ")
    }
}
