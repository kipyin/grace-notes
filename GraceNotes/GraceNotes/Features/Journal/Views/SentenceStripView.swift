import SwiftUI

struct SentenceStripView: View {
    private enum Layout {
        static let expansionThreshold = 88
        static let softCapLineLimit = 3
    }

    let sectionTitle: String
    let itemPosition: Int
    let itemCount: Int
    let sentence: String
    let accessibilityIdentifier: String?
    let isSelected: Bool
    let isExpanded: Bool
    let isExpandable: Bool
    let expansionAccessibilityIdentifier: String?
    let onTap: () -> Void
    let onToggleExpanded: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        sectionTitle: String,
        itemPosition: Int,
        itemCount: Int,
        sentence: String,
        accessibilityIdentifier: String? = nil,
        isSelected: Bool = false,
        isExpanded: Bool = false,
        isExpandable: Bool = false,
        expansionAccessibilityIdentifier: String? = nil,
        onTap: @escaping () -> Void,
        onToggleExpanded: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.sectionTitle = sectionTitle
        self.itemPosition = itemPosition
        self.itemCount = itemCount
        self.sentence = sentence
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        self.isExpandable = isExpandable
        self.expansionAccessibilityIdentifier = expansionAccessibilityIdentifier
        self.onTap = onTap
        self.onToggleExpanded = onToggleExpanded
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowButton
            if isExpandable, let onToggleExpanded {
                Button(action: onToggleExpanded) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? String(localized: "Show less") : String(localized: "Show more"))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AppTheme.outfitSemiboldCaption)
                    }
                    .font(AppTheme.outfitSemiboldSubheadline)
                    .foregroundStyle(AppTheme.accentText)
                    .padding(.leading, AppTheme.spacingRegular)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .modifier(
                    SequentialSectionChipRow.ConditionalAccessibilityIdentifier(
                        identifier: expansionAccessibilityIdentifier
                    )
                )
                .accessibilityHint(String(localized: "Expands or collapses the sentence preview"))
            }
        }
    }

    private var rowButton: some View {
        Button(action: onTap) {
            Text(sentence)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.journalTextPrimary)
                .lineLimit(isExpanded ? nil : Layout.softCapLineLimit)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.spacingRegular)
                .padding(.vertical, AppTheme.spacingRegular)
                .frame(minHeight: 50, alignment: .leading)
                .background(
                    isSelected
                        ? AppTheme.journalActiveEditingAccent.opacity(0.24)
                        : AppTheme.journalPaper.opacity(0.72)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(
                            isSelected
                                ? AppTheme.journalActiveEditingAccentStrong.opacity(0.86)
                                : AppTheme.journalInputBorder.opacity(0.76),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .buttonStyle(WarmPaperPressStyle())
        .contentShape(.rect)
        .contextMenu {
            if onDelete != nil {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label(String(localized: "Delete"), systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityValue(sentence)
        .accessibilityHint(rowAccessibilityHint)
        .modifier(
            SequentialSectionChipRow.ConditionalAccessibilityIdentifier(
                identifier: accessibilityIdentifier
            )
        )
        .accessibilityAction(named: Text(String(localized: "Delete"))) {
            guard onDelete != nil else { return }
            onDelete?()
        }
    }

    private var rowAccessibilityLabel: String {
        String(
            format: String(localized: "%1$@ item %2$d of %3$d"),
            locale: Locale.current,
            sectionTitle,
            itemPosition,
            itemCount
        )
    }

    private var rowAccessibilityHint: String {
        if isExpandable {
            return String(localized: "Double-tap to edit this sentence. Use Show more to preview the full text.")
        }
        return String(localized: "Double-tap to edit this sentence.")
    }

    static func requiresExpandedPreview(_ sentence: String) -> Bool {
        let lineCount = sentence.split(whereSeparator: \.isNewline).count
        return sentence.count > Layout.expansionThreshold || lineCount > Layout.softCapLineLimit
    }
}
