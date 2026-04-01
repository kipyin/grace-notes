import SwiftData
import SwiftUI
import UIKit

enum PastJournalSearchDebouncer {
    @MainActor
    static func runDebouncedSearch(
        query: String,
        calendar: Calendar,
        modelContext: ModelContext,
        updateMatches: @MainActor @escaping ([JournalSearchMatch]) -> Void
    ) async {
        let snapshot = query
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return }
        guard snapshot == query else { return }

        let trimmed = snapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            updateMatches([])
            return
        }

        let repository = JournalRepository(calendar: calendar)
        do {
            let results = try repository.searchMatches(query: trimmed, context: modelContext)
            guard !Task.isCancelled else { return }
            guard snapshot == query else { return }
            updateMatches(results)
        } catch {
            guard snapshot == query else { return }
            updateMatches([])
        }
    }
}

enum PastJournalSearchGrouping {
    /// Groups by calendar day, then by journal section in `ReviewThemeSourceCategory` definition order.
    static func daySections(
        matches: [JournalSearchMatch],
        calendar: Calendar
    ) -> [(
        day: Date,
        sections: [(source: ReviewThemeSourceCategory, rows: [JournalSearchMatch])]
    )] {
        let groupedByDay = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.entryDate) }
        return groupedByDay.keys.sorted(by: >).map { day in
            let dayMatches = groupedByDay[day] ?? []
            let bySource = Dictionary(grouping: dayMatches) { $0.source }
            let sections: [(source: ReviewThemeSourceCategory, rows: [JournalSearchMatch])] =
                ReviewThemeSourceCategory.allCases.compactMap { source in
                    guard let rows = bySource[source], !rows.isEmpty else { return nil }
                    let sortedRows = rows.sorted {
                        $0.content.localizedCaseInsensitiveCompare($1.content) == .orderedAscending
                    }
                    return (source: source, rows: sortedRows)
                }
            return (day, sections)
        }
    }
}

private struct PastJournalSearchBarChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.reviewTextMuted)
                .accessibilityHidden(true)
            content()
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
    }
}

struct PastJournalSearchBar: View {
    @Binding var text: String
    private let searchFocus: FocusState<Bool>.Binding?

    init(text: Binding<String>, searchFocus: FocusState<Bool>.Binding? = nil) {
        _text = text
        self.searchFocus = searchFocus
    }

    var body: some View {
        PastJournalSearchBarChrome {
            Group {
                if let searchFocus {
                    TextField(String(localized: "Search journal"), text: $text)
                        .focused(searchFocus)
                } else {
                    TextField(String(localized: "Search journal"), text: $text)
                }
            }
            .textFieldStyle(.plain)
            .submitLabel(.search)
            .accessibilityLabel(String(localized: "Search journal"))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Search pill plus trailing dismiss control outside the chrome (Past tab).
struct PastJournalSearchFieldRow: View {
    private enum Metrics {
        /// Dismiss slot animates 0 → this width so the pill and control stay layout-locked (no faded overlap).
        static let dismissSlotWidth: CGFloat = 44
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var text: String
    var searchFocus: FocusState<Bool>.Binding

    /// Synced from focus with `withAnimation` so tap-to-focus animates; the system does not animate `FocusState`.
    @State private var showDismissChrome = false

    private var isSearchFocused: Bool {
        searchFocus.wrappedValue
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PastJournalSearchBar(text: $text, searchFocus: searchFocus)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: dismissSearchControlTapped) {
                Image(systemName: "xmark")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(AppTheme.reviewTextMuted)
            }
            .buttonStyle(.plain)
            .frame(width: Metrics.dismissSlotWidth, height: Metrics.dismissSlotWidth)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "PastSearch.dismissControl.a11yLabel"))
            .accessibilityHint(String(localized: "PastSearch.dismissControl.a11yHint"))
            .accessibilityHidden(!showDismissChrome)
            .allowsHitTesting(showDismissChrome)
            .frame(width: showDismissChrome ? Metrics.dismissSlotWidth : 0, alignment: .trailing)
            .clipped()
        }
        .onAppear {
            showDismissChrome = isSearchFocused
        }
        .onChange(of: isSearchFocused) { _, newValue in
            if reduceMotion {
                showDismissChrome = newValue
            } else {
                withAnimation(.snappy(duration: 0.22)) {
                    showDismissChrome = newValue
                }
            }
        }
    }

    private func dismissSearchControlTapped() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if reduceMotion {
            if !trimmed.isEmpty {
                text = ""
            }
            searchFocus.wrappedValue = false
        } else {
            withAnimation(.snappy(duration: 0.22)) {
                if !trimmed.isEmpty {
                    text = ""
                }
                searchFocus.wrappedValue = false
            }
        }
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct PastJournalSearchDayCard: View {
    let day: Date
    let sections: [(source: ReviewThemeSourceCategory, rows: [JournalSearchMatch])]
    let onDismissSearchFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(day.formatted(date: .abbreviated, time: .omitted))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onDismissSearchFocus() }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections, id: \.source) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.source.localizedJournalSurfaceTitle)
                            .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { onDismissSearchFocus() }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(section.rows) { match in
                                NavigationLink {
                                    JournalScreen(entryDate: match.entryDate)
                                        .id(match.id)
                                } label: {
                                    Text(match.content)
                                        .font(AppTheme.warmPaperBody)
                                        .foregroundStyle(AppTheme.reviewTextPrimary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(rowAccessibilityLabel(day: day, match: match))
                                .accessibilityHint(String(localized: "ThemeDrilldown.openEntry.a11yHint"))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .fill(AppTheme.reviewPaper.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .strokeBorder(AppTheme.reviewStandardBorder.opacity(0.42), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .circular))
    }

    private func rowAccessibilityLabel(day: Date, match: JournalSearchMatch) -> String {
        let dayText = day.formatted(date: .abbreviated, time: .omitted)
        return [dayText, match.source.localizedJournalSurfaceTitle, match.content].joined(separator: ", ")
    }
}

struct PastJournalSearchResultsList: View {
    let isAwaitingInput: Bool
    let matches: [JournalSearchMatch]
    let calendar: Calendar
    let onDismissSearchFocus: () -> Void

    private var daySectionGroups: [(
        day: Date,
        sections: [(source: ReviewThemeSourceCategory, rows: [JournalSearchMatch])]
    )] {
        PastJournalSearchGrouping.daySections(matches: matches, calendar: calendar)
    }

    private var searchEmptyStateMessage: String {
        if isAwaitingInput {
            String(localized: "PastSearch.awaitingInput.subtitle")
        } else {
            String(localized: "PastSearch.noMatches.description")
        }
    }

    var body: some View {
        Group {
            if matches.isEmpty {
                Section {
                    Text(searchEmptyStateMessage)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismissSearchFocus()
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.reviewBackground)
                }
            } else {
                Section {
                    ForEach(daySectionGroups, id: \.day) { group in
                        PastJournalSearchDayCard(
                            day: group.day,
                            sections: group.sections,
                            onDismissSearchFocus: onDismissSearchFocus
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(String(localized: "Matching writing surfaces"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismissSearchFocus()
                        }
                }
            }
        }
    }
}
