import Foundation

/// Evidence rules for optional cloud Review insights (`GraceNotes/docs/03-review-insight-quality-contract.md`).
enum ReviewInsightsCloudEligibility {
    /// Fewer than this many meaningful journal rows in the selected week skips the cloud path.
    static let minimumMeaningfulEntriesForCloudAI = 3

    static func currentWeekRange(containing referenceDate: Date, calendar: Calendar) -> Range<Date> {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return start..<end
    }

    /// Journal rows in `weekRange` with ``JournalEntry/hasMeaningfulContent``.
    static func meaningfulEntryCount(in entries: [JournalEntry], weekRange: Range<Date>) -> Int {
        entries.reduce(0) { count, entry in
            guard weekRange.contains(entry.entryDate), entry.hasMeaningfulContent else { return count }
            return count + 1
        }
    }

    static func hasMinimumEvidenceForCloudAI(
        entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let range = currentWeekRange(containing: referenceDate, calendar: calendar)
        return meaningfulEntryCount(in: entries, weekRange: range) >= minimumMeaningfulEntriesForCloudAI
    }
}
