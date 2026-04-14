import SwiftUI

private struct EntryRowDeleteAccessibilityAction: ViewModifier {
    let onDelete: (() -> Void)?

    func body(content: Content) -> some View {
        if let onDelete {
            content.accessibilityAction(named: Text(String(localized: "common.delete")), onDelete)
        } else {
            content
        }
    }
}

struct SequentialEntryRowView: View {
    @Environment(\.todayJournalPalette) private var palette
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

    /// Matches when the show-more / show-less control is actually present (see `body`).
    private var showsExpansionControls: Bool {
        isExpandable && onToggleExpanded != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowButton
            if showsExpansionControls, let onToggleExpanded {
                Button(action: onToggleExpanded) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? String(localized: "common.showLess") : String(localized: "common.showMore"))
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
                    SequentialSectionEntryRow.ConditionalAccessibilityIdentifier(
                        identifier: expansionAccessibilityIdentifier
                    )
                )
                .accessibilityHint(String(localized: "accessibility.expandCollapsePreview"))
            }
        }
    }

    private var rowButton: some View {
        Button(action: onTap) {
            Text(sentence)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(isExpanded ? nil : Layout.softCapLineLimit)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.spacingRegular)
                .padding(.vertical, AppTheme.spacingRegular)
                .frame(minHeight: 50, alignment: .leading)
                .background(
                    isSelected
                        ? palette.activeEditingAccent.opacity(0.24)
                        : palette.paper.opacity(0.72 * palette.sectionPaperOpacity)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(
                            isSelected
                                ? palette.activeEditingAccentStrong.opacity(0.86)
                                : palette.inputBorder.opacity(0.76),
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
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityValue(sentence)
        .accessibilityHint(rowAccessibilityHint)
        .modifier(
            SequentialSectionEntryRow.ConditionalAccessibilityIdentifier(
                identifier: accessibilityIdentifier
            )
        )
        .modifier(EntryRowDeleteAccessibilityAction(onDelete: onDelete))
    }

    private var rowAccessibilityLabel: String {
        String(
            format: String(localized: "accessibility.list.itemPosition"),
            locale: Locale.current,
            sectionTitle,
            itemPosition,
            itemCount
        )
    }

    private var rowAccessibilityHint: String {
        if showsExpansionControls {
            return String(localized: "accessibility.tapToEditSentenceShowMore")
        }
        return String(localized: "accessibility.tapToEditSentence")
    }

    static func requiresExpandedPreview(_ sentence: String) -> Bool {
        let lineCount = sentence.split(whereSeparator: \.isNewline).count
        return sentence.count > Layout.expansionThreshold || lineCount > Layout.softCapLineLimit
    }
}
