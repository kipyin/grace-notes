import Foundation

struct ExportHistoryLineParts {
    let kindLabel: String
    let statusLabel: String
    /// Non-nil when `entry.detail` is non-empty (same rule as on-screen history).
    let detail: String?
}

enum ImportExportTechnicalDetailFormatting {
    /// Returns true when `detail` should use monospace: non-empty, no whitespace, and ends with `.json`
    /// (case-insensitive). Localized failure messages and sentences stay false for Warm Paper meta fonts.
    static func detailLooksLikeFileName(_ detail: String) -> Bool {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.contains(where: { $0.isWhitespace }) { return false }
        return trimmed.lowercased().hasSuffix(".json")
    }

    /// Shared kind/status/detail strings for export history on-screen text and plain accessibility labels.
    static func exportHistoryLineParts(for entry: BackupExportHistoryEntry) -> ExportHistoryLineParts {
        let kindLabel: String
        switch entry.kind {
        case .manualShare:
            kindLabel = String(localized: "settings.dataPrivacy.importExport.history.kind.manual")
        case .manualFolder:
            kindLabel = String(localized: "settings.dataPrivacy.importExport.history.kind.manualFolder")
        case .scheduledFolder:
            kindLabel = String(localized: "settings.dataPrivacy.importExport.history.kind.scheduled")
        }
        let statusLabel: String
        if entry.success {
            statusLabel = String(localized: "settings.dataPrivacy.importExport.history.status.success")
        } else {
            statusLabel = String(localized: "settings.dataPrivacy.importExport.history.status.failed")
        }
        let detail: String?
        if let raw = entry.detail, !raw.isEmpty {
            detail = raw
        } else {
            detail = nil
        }
        return ExportHistoryLineParts(kindLabel: kindLabel, statusLabel: statusLabel, detail: detail)
    }

    /// Single-line label matching the visible history line (fonts aside), for VoiceOver and string-only use.
    static func exportHistoryPlainLabel(for entry: BackupExportHistoryEntry) -> String {
        let parts = exportHistoryLineParts(for: entry)
        if let detail = parts.detail {
            return "\(parts.kindLabel) · \(parts.statusLabel) · \(detail)"
        }
        return "\(parts.kindLabel) · \(parts.statusLabel)"
    }
}
