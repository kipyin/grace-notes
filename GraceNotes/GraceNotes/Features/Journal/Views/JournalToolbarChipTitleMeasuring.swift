import UIKit

enum JournalToolbarChipTitleMeasuring {
    /// Matches ``AppTheme/warmPaperToolbarChipTitle`` (16pt Source Serif semibold, `relativeTo: .body`).
    static func toolbarChipTitleUIFont(forTextStyle textStyle: UIFont.TextStyle = .body) -> UIFont {
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        let size: CGFloat = 16
        guard let regular = UIFont(name: "SourceSerif4Roman-Regular", size: size) else {
            return metrics.scaledFont(for: UIFont.preferredFont(forTextStyle: textStyle))
        }
        let semiboldDescriptor = regular.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName.traits: [
                UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold
            ]
        ])
        let semibold = UIFont(descriptor: semiboldDescriptor, size: size)
        return metrics.scaledFont(for: semibold)
    }

    static func singleLineTextWidth(_ text: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).size
        return ceil(size.width)
    }

    /// `+2` pt slack so SwiftUI layout does not underflow UIKit measurement at fractional pixels.
    static func measuredToolbarChipTitleWidth(for title: String) -> CGFloat {
        singleLineTextWidth(title, font: toolbarChipTitleUIFont(forTextStyle: .body)) + 2
    }
}
