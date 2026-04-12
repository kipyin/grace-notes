import Foundation

/// Drops redundant rapid taps on the same journal sentence row (same entry id) to avoid
/// overlapping `performEntryTap` / focus work. Only updates state when a tap is accepted.
enum EntryRowTapDebounce {
    /// Production interval for same-row repeat taps (`SequentialSectionPrimaryColumn`).
    static let sameRowTapDebounceInterval: TimeInterval = 0.35

    static func shouldProcessTap(
        itemID: UUID,
        at date: Date,
        lastAcceptedItemID: inout UUID?,
        lastAcceptedDate: inout Date?,
        interval: TimeInterval
    ) -> Bool {
        let window = max(0, interval)

        guard let priorID = lastAcceptedItemID,
              let priorDate = lastAcceptedDate,
              priorID == itemID,
              date >= priorDate
        else {
            lastAcceptedItemID = itemID
            lastAcceptedDate = date
            return true
        }

        if date.timeIntervalSince(priorDate) < window {
            return false
        }

        lastAcceptedItemID = itemID
        lastAcceptedDate = date
        return true
    }
}
