import SwiftData
import SwiftUI
import UIKit

enum PastJournalSearchDebouncer {
    @MainActor
    static func runDebouncedSearch(
        query: String,
        calendar: Calendar,
        modelContext: ModelContext,
        isTrimmedQueryStillCurrent: @escaping @MainActor (String) -> Bool,
        updateMatches: @escaping @MainActor ([JournalSearchMatch]) -> Void
    ) async {
        let trimmedEarly = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEarly.isEmpty {
            updateMatches([])
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        guard isTrimmedQueryStillCurrent(trimmedEarly) else { return }

        let container = modelContext.container
        let cal = calendar
        let trimmed = trimmedEarly

        do {
            let results = try await Task.detached(priority: .userInitiated) {
                let backgroundContext = ModelContext(container)
                let repository = JournalRepository(calendar: cal)
                return try repository.searchMatches(query: trimmed, context: backgroundContext, maxRows: 200)
            }.value

            guard !Task.isCancelled else { return }
            guard isTrimmedQueryStillCurrent(trimmed) else { return }
            updateMatches(results)
        } catch is CancellationError {
            return
        } catch {
            guard isTrimmedQueryStillCurrent(trimmed) else { return }
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
                        let ordering = $0.content.localizedCaseInsensitiveCompare($1.content)
                        if ordering != .orderedSame {
                            return ordering == .orderedAscending
                        }
                        return $0.id < $1.id
                    }
                    return (source: source, rows: sortedRows)
                }
            return (day, sections)
        }
    }
}

/// File-scoped highlight rendering; ``text(content:highlightQuery:)`` is the only entry point used by views.
private enum PastJournalSearchHighlighting {
    /// Body size matches ``AppTheme.warmPaperBody`` (17pt, scaled for Dynamic Type).
    private static let bodyPointSize: CGFloat = 17
    private static let serifRegularPostScriptName = "SourceSerif4Roman-Regular"
    private static let matchBackgroundFill = UIColor(AppTheme.reviewAccent).withAlphaComponent(0.15)
    private static var bodyTextColor: UIColor { UIColor(AppTheme.reviewTextPrimary) }

    private static func bodyUIFont(semibold: Bool) -> UIFont {
        let size = UIFontMetrics(forTextStyle: .body).scaledValue(for: bodyPointSize)
        guard let base = UIFont(name: serifRegularPostScriptName, size: size) else {
            return UIFont.preferredFont(forTextStyle: .body)
        }
        if !semibold { return base }
        let boldTraits = base.fontDescriptor.symbolicTraits.union(.traitBold)
        guard let boldDescriptor = base.fontDescriptor.withSymbolicTraits(boldTraits) else { return base }
        return UIFont(descriptor: boldDescriptor, size: size)
    }

    /// `private` to this enum so new call sites cannot skip trimming; empty `trimmedQuery` returns `[]` because
    /// `range(of:options:range:locale:)` would yield zero-width matches without advancing and could spin on the main
    /// actor.
    private static func matchRanges(for content: String, trimmedQuery: String) -> [Range<String.Index>] {
        guard !trimmedQuery.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchStart = content.startIndex
        while searchStart < content.endIndex,
              let found = content.range(
                of: trimmedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart ..< content.endIndex,
                locale: .current
              ) {
            ranges.append(found)
            searchStart = found.upperBound
        }
        return ranges
    }

    static func text(content: String, highlightQuery: String) -> Text {
        let trimmed = highlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let ranges: [Range<String.Index>] = if trimmed.isEmpty {
            []
        } else {
            matchRanges(for: content, trimmedQuery: trimmed)
        }

        let mutable = NSMutableAttributedString(string: content)
        let full = NSRange(location: 0, length: (content as NSString).length)
        mutable.addAttribute(.font, value: bodyUIFont(semibold: false), range: full)
        mutable.addAttribute(.foregroundColor, value: bodyTextColor, range: full)

        for matchRange in ranges {
            let nsr = NSRange(matchRange, in: content)
            guard nsr.length > 0 else { continue }
            mutable.addAttribute(.font, value: bodyUIFont(semibold: true), range: nsr)
            mutable.addAttribute(.backgroundColor, value: matchBackgroundFill, range: nsr)
        }

        return Text(AttributedString(mutable))
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
                    TextField(String(localized: "past.search.placeholder"), text: $text)
                        .focused(searchFocus)
                } else {
                    TextField(String(localized: "past.search.placeholder"), text: $text)
                }
            }
            .textFieldStyle(.plain)
            .submitLabel(.search)
            .accessibilityLabel(String(localized: "past.search.placeholder"))
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
            .buttonStyle(PastTappablePressStyle())
            .frame(width: Metrics.dismissSlotWidth, height: Metrics.dismissSlotWidth)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "past.search.dismissControl.a11yLabel"))
            .accessibilityHint(String(localized: "past.search.dismissControl.a11yHint"))
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
    let calendar: Calendar
    let highlightQuery: String
    let onOpenJournalDay: (Date) -> Void

    private var dayCaption: String {
        PastSearchDayCaption.string(day: day, now: Date(), calendar: calendar)
    }

    var body: some View {
        Button {
            onOpenJournalDay(day)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text(dayCaption)
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.reviewTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(sections, id: \.source) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.source.localizedJournalSurfaceTitle)
                                .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                                .foregroundStyle(AppTheme.reviewTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(section.rows) { match in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        PastJournalSearchHighlighting.text(
                                            content: match.content,
                                            highlightQuery: highlightQuery
                                        )
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.reviewTextMuted)
                                            .imageScale(.small)
                                            .accessibilityHidden(true)
                                    }
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
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .circular))
        }
        .buttonStyle(PastTappablePressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayCaption)
        .accessibilityHint(String(localized: "review.themeDrilldown.openEntry.a11yHint"))
    }
}

struct PastJournalSearchResultsList: View {
    let isAwaitingInput: Bool
    let matches: [JournalSearchMatch]
    let calendar: Calendar
    let highlightQuery: String
    let onDismissSearchFocus: () -> Void
    let onOpenJournalDay: (Date) -> Void

    private var daySectionGroups: [(
        day: Date,
        sections: [(source: ReviewThemeSourceCategory, rows: [JournalSearchMatch])]
    )] {
        PastJournalSearchGrouping.daySections(matches: matches, calendar: calendar)
    }

    private var searchEmptyStateMessage: String {
        if isAwaitingInput {
            String(localized: "past.search.awaitingInput.subtitle")
        } else {
            String(localized: "past.search.noMatches.description")
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
                            calendar: calendar,
                            highlightQuery: highlightQuery,
                            onOpenJournalDay: onOpenJournalDay
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
    }
}
