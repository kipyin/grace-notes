import Foundation

/// Evidence rules for optional cloud Review insights (`GraceNotes/docs/03-review-insight-quality-contract.md`).
enum ReviewInsightsCloudEligibility {
    /// Fewer than this many meaningful journal rows in the selected review period skips the cloud path.
    static let minimumMeaningfulEntriesForCloudAI = 3

    static func currentReviewPeriod(containing referenceDate: Date, calendar: Calendar) -> Range<Date> {
        ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
    }

    /// Journal rows in `period` with ``JournalEntry/hasMeaningfulContent``.
    static func meaningfulEntryCount(in entries: [JournalEntry], period: Range<Date>) -> Int {
        entries.reduce(0) { count, entry in
            guard period.contains(entry.entryDate), entry.hasMeaningfulContent else { return count }
            return count + 1
        }
    }

    static func hasMinimumEvidenceForCloudAI(
        entries: [JournalEntry],
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let range = currentReviewPeriod(containing: referenceDate, calendar: calendar)
        return meaningfulEntryCount(in: entries, period: range) >= minimumMeaningfulEntriesForCloudAI
    }
}
