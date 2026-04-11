import Foundation

enum PastStatisticsIntervalMode: String, Codable, Equatable, Sendable {
    case all
    case custom
}

enum PastStatisticsIntervalUnit: String, Codable, Equatable, CaseIterable, Sendable {
    case week
    case month
    case year
}

struct PastStatisticsIntervalSelection: Codable, Equatable, Hashable, Sendable {
    var mode: PastStatisticsIntervalMode
    /// Used when ``mode`` is ``custom``; clamped to 1...999.
    var quantity: Int
    var unit: PastStatisticsIntervalUnit

    static let `default` = PastStatisticsIntervalSelection(mode: .all, quantity: 4, unit: .week)

    init(mode: PastStatisticsIntervalMode, quantity: Int, unit: PastStatisticsIntervalUnit) {
        self.mode = mode
        self.quantity = quantity
        self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(PastStatisticsIntervalMode.self, forKey: .mode)
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 4
        unit = try container.decodeIfPresent(PastStatisticsIntervalUnit.self, forKey: .unit) ?? .week
    }

    var validated: PastStatisticsIntervalSelection {
        var copy = self
        if copy.mode == .custom {
            copy.quantity = min(max(copy.quantity, 1), 999)
        }
        return copy
    }

    /// Past statistics window: local calendar days from resolved lower bound through ``referenceDate`` (inclusive).
    func resolvedHistoryRange(
        referenceDate: Date,
        calendar: Calendar,
        allEntries: [Journal]
    ) -> Range<Date> {
        let refStart = calendar.startOfDay(for: referenceDate)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: refStart) else {
            return refStart..<refStart
        }
        switch mode {
        case .all:
            let days = allEntries.map { calendar.startOfDay(for: $0.entryDate) }
            let earliest = days.min() ?? refStart
            // Cap at `refStart` so `lower < endExclusive` when every entry is dated after the reference day
            // (import/clock skew); otherwise `Range` construction traps.
            let lower = min(earliest, refStart)
            return lower..<endExclusive
        case .custom:
            let quantityValue = min(max(quantity, 1), 999)
            let anchor = refStart
            let startCandidate: Date?
            switch unit {
            case .week:
                startCandidate = calendar.date(byAdding: .weekOfYear, value: -quantityValue, to: anchor)
            case .month:
                startCandidate = calendar.date(byAdding: .month, value: -quantityValue, to: anchor)
            case .year:
                startCandidate = calendar.date(byAdding: .year, value: -quantityValue, to: anchor)
            }
            let startDay = calendar.startOfDay(for: startCandidate ?? anchor)
            return startDay..<endExclusive
        }
    }

    var cacheKeyToken: String {
        let toEncode = validated
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(toEncode) else {
            return "default"
        }
        return data.base64EncodedString()
    }

    static func decode(from appStorageRaw: String) -> PastStatisticsIntervalSelection {
        guard !appStorageRaw.isEmpty,
              let data = appStorageRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PastStatisticsIntervalSelection.self, from: data)
        else {
            return PastStatisticsIntervalSelection.default.validated
        }
        return decoded.validated
    }

    static func encodeForStorage(_ selection: PastStatisticsIntervalSelection) -> String {
        let toEncode = selection.validated
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(toEncode) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension PastStatisticsIntervalSelection {
    /// Short phrase describing the interval for subtitles (e.g. Most recurring drilldown).
    func statisticsIntervalSubtitlePhrase() -> String {
        let selection = validated
        switch selection.mode {
        case .all:
            return String(localized: "settings.pastStatisticsInterval.phrase.allJournal")
        case .custom:
            let count = Int64(selection.quantity)
            switch selection.unit {
            case .week:
                if selection.quantity == 1 {
                    return String(localized: "settings.pastStatisticsInterval.phrase.lastOneWeek")
                }
                return String(format: String(localized: "settings.pastStatisticsInterval.phrase.lastNWeeks"), count)
            case .month:
                if selection.quantity == 1 {
                    return String(localized: "settings.pastStatisticsInterval.phrase.lastOneMonth")
                }
                return String(format: String(localized: "settings.pastStatisticsInterval.phrase.lastNMonths"), count)
            case .year:
                if selection.quantity == 1 {
                    return String(localized: "settings.pastStatisticsInterval.phrase.lastOneYear")
                }
                return String(format: String(localized: "settings.pastStatisticsInterval.phrase.lastNYears"), count)
            }
        }
    }

    func mostRecurringDrilldownSubtitle(mentionCount: Int) -> String {
        let interval = statisticsIntervalSubtitlePhrase()
        return String(
            format: String(localized: "review.mostRecurring.drilldown.subtitle"),
            Int64(mentionCount),
            interval
        )
    }
}

enum PastStatisticsIntervalPreference {
    static let appStorageKey = "pastStatisticsInterval.selection.v1"
    private static let legacyBrowseWindowsKey = "GraceNotes.mostRecurringBrowseWindowWeeks"

    static func selection(fromAppStorage raw: String) -> PastStatisticsIntervalSelection {
        PastStatisticsIntervalSelection.decode(from: raw)
    }

    static func bootstrapUserDefaultsIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: appStorageKey) == nil else { return }
        if let weeks = defaults.object(forKey: legacyBrowseWindowsKey) as? Int, [2, 4, 8].contains(weeks) {
            let migrated = PastStatisticsIntervalSelection(mode: .custom, quantity: weeks, unit: .week).validated
            defaults.set(PastStatisticsIntervalSelection.encodeForStorage(migrated), forKey: appStorageKey)
            defaults.removeObject(forKey: legacyBrowseWindowsKey)
        }
    }
}
