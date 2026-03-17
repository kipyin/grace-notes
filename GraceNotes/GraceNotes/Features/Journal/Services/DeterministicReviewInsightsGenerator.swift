import Foundation

struct DeterministicReviewInsightsGenerator: ReviewInsightsGenerating {
    private let maxThemesPerSection = 3

    func generateInsights(
        from entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar = .current
    ) async throws -> ReviewInsights {
        let weekRange = weekDateRange(containing: referenceDate, calendar: calendar)
        let weeklyEntries = entries.filter { weekRange.contains($0.entryDate) }

        let recurringGratitudes = topThemes(
            from: weeklyEntries.flatMap(\.gratitudes).map(\.displayLabel)
        )
        let recurringNeeds = topThemes(
            from: weeklyEntries.flatMap(\.needs).map(\.displayLabel)
        )
        let recurringPeople = topThemes(
            from: weeklyEntries.flatMap(\.people).map(\.displayLabel)
        )

        return ReviewInsights(
            source: .deterministic,
            generatedAt: referenceDate,
            weekStart: weekRange.lowerBound,
            weekEnd: weekRange.upperBound,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            resurfacingMessage: resurfacingMessage(
                entries: weeklyEntries,
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople
            ),
            continuityPrompt: continuityPrompt(
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople
            ),
            narrativeSummary: narrativeSummary(
                entries: weeklyEntries,
                recurringGratitudes: recurringGratitudes,
                recurringNeeds: recurringNeeds,
                recurringPeople: recurringPeople
            )
        )
    }

    private func weekDateRange(containing date: Date, calendar: Calendar) -> Range<Date> {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return start..<end
    }

    private func topThemes(from labels: [String]) -> [ReviewInsightTheme] {
        let normalized = labels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(normalizeThemeLabel)

        var counts: [String: Int] = [:]
        for item in normalized {
            counts[item, default: 0] += 1
        }
        return counts
            .map { ReviewInsightTheme(label: denormalizeThemeLabel($0.key), count: $0.value) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            .prefix(maxThemesPerSection)
            .map { $0 }
    }

    private func resurfacingMessage(
        entries: [JournalEntry],
        recurringGratitudes: [ReviewInsightTheme],
        recurringNeeds: [ReviewInsightTheme],
        recurringPeople: [ReviewInsightTheme]
    ) -> String {
        if let topNeed = recurringNeeds.first, topNeed.count > 1 {
            return "You mentioned \(topNeed.label) \(topNeed.count) times this week."
        }
        if let topPerson = recurringPeople.first, topPerson.count > 1 {
            return "You kept \(topPerson.label) in mind \(topPerson.count) times this week."
        }
        if let topGratitude = recurringGratitudes.first, topGratitude.count > 1 {
            return "You returned to \(topGratitude.label) \(topGratitude.count) times this week."
        }

        if entries.isEmpty {
            return "Start with one reflection today to build your weekly review."
        }

        return "You showed up for reflection on \(entries.count) day\(entries.count == 1 ? "" : "s") this week."
    }

    private func continuityPrompt(
        recurringGratitudes: [ReviewInsightTheme],
        recurringNeeds: [ReviewInsightTheme],
        recurringPeople: [ReviewInsightTheme]
    ) -> String {
        if let topNeed = recurringNeeds.first {
            return "What is one small step you can take to support \(topNeed.label) tomorrow?"
        }
        if let topPerson = recurringPeople.first {
            return "How could you connect with \(topPerson.label) in a meaningful way this week?"
        }
        if let topGratitude = recurringGratitudes.first {
            return "How can you carry \(topGratitude.label) into tomorrow?"
        }
        return "What feels most important to carry into next week?"
    }

    private func narrativeSummary(
        entries: [JournalEntry],
        recurringGratitudes: [ReviewInsightTheme],
        recurringNeeds: [ReviewInsightTheme],
        recurringPeople: [ReviewInsightTheme]
    ) -> String? {
        guard !entries.isEmpty else { return nil }

        var parts: [String] = []
        if let gratitude = recurringGratitudes.first {
            parts.append("gratitude around \(gratitude.label)")
        }
        if let need = recurringNeeds.first {
            parts.append("a recurring need for \(need.label)")
        }
        if let person = recurringPeople.first {
            parts.append("care for \(person.label)")
        }

        if parts.isEmpty {
            return "You kept a steady reflection rhythm this week."
        }

        let joined = ListFormatter.localizedString(byJoining: parts)
        return "This week you reflected on \(joined)."
    }

    private func normalizeThemeLabel(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func denormalizeThemeLabel(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased() + value.dropFirst()
    }
}
