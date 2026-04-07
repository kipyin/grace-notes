import Foundation

/// Drops redundant rapid taps on the same journal sentence row (same entry id) to avoid
/// overlapping `performEntryTap` / focus work. Only updates state when a tap is accepted.
enum EntryRowTapDebounce {
    static func shouldProcessTap(
        itemID: UUID,
        at date: Date,
        lastAcceptedItemID: inout UUID?,
        lastAcceptedDate: inout Date?,
        interval: TimeInterval
    ) -> Bool {
        if let priorID = lastAcceptedItemID,
           let priorDate = lastAcceptedDate,
           priorID == itemID,
           date.timeIntervalSince(priorDate) < interval {
            return false
        }
        lastAcceptedItemID = itemID
        lastAcceptedDate = date
        return true
    }
}
