import Foundation

struct ChipLabelUnitTruncator {
    static let maxUnits = 10

    static func truncate(_ text: String, maxUnits: Int = maxUnits) -> SummarizationResult {
        guard !text.isEmpty else { return SummarizationResult(label: "", isTruncated: false) }

        var label = ""
        var usedUnits = 0
        var didTruncate = false

        for character in text {
            let units = unitCount(for: character)
            if usedUnits + units > maxUnits {
                didTruncate = true
                break
            }
            label.append(character)
            usedUnits += units
        }

        if !didTruncate {
            didTruncate = label.count < text.count
        }

        return SummarizationResult(label: label, isTruncated: didTruncate)
    }

    private static func unitCount(for character: Character) -> Int {
        character.containsHanScalar ? 2 : 1
    }

    static func isHanScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2CEB0...0x2EBEF,
             0x2F800...0x2FA1F:
            return true
        default:
            return false
        }
    }
}

private extension Character {
    var containsHanScalar: Bool {
        unicodeScalars.contains { ChipLabelUnitTruncator.isHanScalar($0) }
    }
}
