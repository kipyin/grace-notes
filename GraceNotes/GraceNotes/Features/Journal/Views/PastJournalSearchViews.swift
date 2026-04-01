import SwiftData
import SwiftUI

enum PastJournalSearchRoute: Hashable {
    case journalSearch
}

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

private enum PastSearchListLayout {
    static var rowInsets: EdgeInsets {
        let inset = AppTheme.spacingWide
        return EdgeInsets(top: 2, leading: inset, bottom: 6, trailing: inset)
    }

    static var searchBarRowInsets: EdgeInsets {
        let inset = AppTheme.spacingWide
        return EdgeInsets(top: 6, leading: inset, bottom: 8, trailing: inset)
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

private struct PastJournalSearchBarChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.reviewTextMuted)
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

struct PastJournalSearchActivationRow: View {
    let query: String

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        PastJournalSearchBarChrome {
            if trimmed.isEmpty {
                Text(String(localized: "Search journal"))
                    .font(.body)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(query)
                    .font(.body)
                    .foregroundStyle(AppTheme.reviewTextPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Search journal"))
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
        }
        .accessibilityElement(children: .combine)
    }
}

struct PastJournalSearchScreen: View {
    @Binding var text: String
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isSearchFieldFocused: Bool
    @State private var matches: [JournalSearchMatch] = []

    private var trimmedQuery: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            Section {
                PastJournalSearchBar(text: $text, searchFocus: $isSearchFieldFocused)
                    .listRowInsets(PastSearchListLayout.searchBarRowInsets)
                    .listRowBackground(AppTheme.reviewBackground)
                    .listRowSeparator(.hidden)
            }
            if !trimmedQuery.isEmpty {
                PastJournalSearchResultsList(matches: matches, calendar: calendar)
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
        .listRowSpacing(10)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(AppTheme.reviewBackground)
        .navigationTitle(String(localized: "Search journal"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
        .task(id: text) {
            await PastJournalSearchDebouncer.runDebouncedSearch(
                query: text,
                calendar: calendar,
                modelContext: modelContext,
                updateMatches: { matches = $0 }
            )
        }
        .onAppear {
            restoreSearchFieldFocus()
        }
    }

    private func restoreSearchFieldFocus() {
        isSearchFieldFocused = true
        Task { @MainActor in
            await Task.yield()
            if !isSearchFieldFocused {
                isSearchFieldFocused = true
            }
        }
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
