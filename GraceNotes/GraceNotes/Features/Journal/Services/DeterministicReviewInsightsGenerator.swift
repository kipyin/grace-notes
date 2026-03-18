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
        var counts: [String: Int] = [:]
        var displayLabels: [String: String] = [:]

        for label in labels {
            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLabel.isEmpty else { continue }

            let normalizedLabel = normalizeThemeLabel(trimmedLabel)
            counts[normalizedLabel, default: 0] += 1
            if displayLabels[normalizedLabel] == nil {
                // Preserve the user's original casing and mixed-language phrasing.
                displayLabels[normalizedLabel] = trimmedLabel
            }
        }

        return counts
            .map {
                let label = displayLabels[$0.key] ?? $0.key
                return ReviewInsightTheme(label: label, count: $0.value)
            }
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
            return String(
                format: String(localized: "You mentioned %1$@ %2$lld times this week."),
                topNeed.label,
                topNeed.count
            )
        }
        if let topPerson = recurringPeople.first, topPerson.count > 1 {
            return String(
                format: String(localized: "You kept %1$@ in mind %2$lld times this week."),
                topPerson.label,
                topPerson.count
            )
        }
        if let topGratitude = recurringGratitudes.first, topGratitude.count > 1 {
            return String(
                format: String(localized: "You returned to %1$@ %2$lld times this week."),
                topGratitude.label,
                topGratitude.count
            )
        }

        if entries.isEmpty {
            return String(localized: "Start with one reflection today to build your weekly review.")
        }

        return String(
            format: String(localized: "You showed up for reflection on %lld day(s) this week."),
            entries.count
        )
    }

    private func continuityPrompt(
        recurringGratitudes: [ReviewInsightTheme],
        recurringNeeds: [ReviewInsightTheme],
        recurringPeople: [ReviewInsightTheme]
    ) -> String {
        if let topNeed = recurringNeeds.first {
            return String(
                format: String(localized: "What is one small step you can take to support %@ tomorrow?"),
                topNeed.label
            )
        }
        if let topPerson = recurringPeople.first {
            return String(
                format: String(localized: "How could you connect with %@ in a meaningful way this week?"),
                topPerson.label
            )
        }
        if let topGratitude = recurringGratitudes.first {
            return String(
                format: String(localized: "How can you carry %@ into tomorrow?"),
                topGratitude.label
            )
        }
        return String(localized: "What feels most important to carry into next week?")
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
            parts.append(
                String(format: String(localized: "gratitude around %@"), gratitude.label)
            )
        }
        if let need = recurringNeeds.first {
            parts.append(
                String(format: String(localized: "a recurring need for %@"), need.label)
            )
        }
        if let person = recurringPeople.first {
            parts.append(
                String(format: String(localized: "care for %@"), person.label)
            )
        }

        if parts.isEmpty {
            return String(localized: "You kept a steady reflection rhythm this week.")
        }

        let joined = ListFormatter.localizedString(byJoining: parts)
        return String(
            format: String(localized: "This week you reflected on %@."),
            joined
        )
    }

    private func normalizeThemeLabel(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
