import Foundation

/// Shapes theme chip text under a journal line so NLP does not show half a sentence as a "tag."
/// Keeps short lines and high-overlap labels intact (e.g. a single name, or a short phrase where the theme dominates).
enum ThemeDrilldownChipDisplayLabel {
    /// Maximum characters shown before truncation when the raw label is too long for the line.
    private static let maxTruncatedLength = 20

    static func label(for concept: ReviewDistilledConcept, lineText: String) -> String {
        let line = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLabel = concept.displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonical = concept.canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawLabel.isEmpty else {
            return canonical.isEmpty ? "…" : canonical
        }
        guard !line.isEmpty else {
            return rawLabel
        }

        let lineCount = line.count
        let labelCount = rawLabel.count

        // Short line: chip can match most of the line (e.g. only a name).
        if lineCount <= 16 {
            return rawLabel
        }

        // Short label relative to a long line: keep as-is.
        if labelCount <= 22 {
            return rawLabel
        }

        // Long label on a long line: avoid pasting a sentence fragment into the chip.
        let halfLine = lineCount / 2
        if labelCount > halfLine && lineCount > 20 {
            return shortenedLabel(rawLabel: rawLabel, canonical: canonical)
        }

        return rawLabel
    }

    private static func shortenedLabel(rawLabel: String, canonical: String) -> String {
        let trimmedCanonical = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCanonical.isEmpty,
           trimmedCanonical.count <= maxTruncatedLength,
           trimmedCanonical.count < rawLabel.count {
            return trimmedCanonical
        }
        if rawLabel.count <= maxTruncatedLength {
            return rawLabel
        }
        let idx = rawLabel.index(rawLabel.startIndex, offsetBy: maxTruncatedLength)
        return String(rawLabel[..<idx]) + "…"
    }
}
