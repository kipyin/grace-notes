import SwiftUI

private enum SequentialSectionEntryScrollerLayout {
    static let edgeFeatherWidth: CGFloat = 28
}

/// Horizontal chip row with scroll metrics, masks, and optional add control.
struct SequentialSectionEntryScroller<ChipRow: View>: View {
    @Environment(\.todayJournalPalette) private var palette
    let reduceMotion: Bool
    let title: String
    let addButtonTitle: String
    let addButtonAccessibilityHint: String
    var showsTrailingChevronOnAddChip: Bool = true
    let showAddChip: Bool
    let addChipAccessibilityIdentifier: String?
    let isInteractionEnabled: Bool
    let canScrollChipsLeft: Bool
    let canScrollChipsRight: Bool
    let onAddNew: (() -> Void)?

    @Binding var entryScrollSnapshot: SequentialSectionEntryRow.EntryRowScrollSnapshot

    @ViewBuilder var chipRow: () -> ChipRow

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingTight) {
                chipRow()
                if showAddChip, let addNew = onAddNew {
                    SequentialSectionEntryRow.AddEntryRowView(
                        buttonTitle: addButtonTitle,
                        accessibilityHint: addButtonAccessibilityHint,
                        accessibilityIdentifier: addChipAccessibilityIdentifier,
                        showsTrailingChevron: showsTrailingChevronOnAddChip,
                        onTap: addNew
                    )
                }
            }
            .padding(.trailing, AppTheme.spacingRegular)
            .scaleEffect(
                x: 1 + entryScrollSnapshot.elasticDeltaX,
                y: 1 + entryScrollSnapshot.elasticDeltaY,
                anchor: .center
            )
            .animation(
                nil,
                value: SequentialSectionEntryRow.EntryRowElasticAnimationKey(
                    deltaX: entryScrollSnapshot.elasticDeltaX,
                    deltaY: entryScrollSnapshot.elasticDeltaY
                )
            )
            .background {
                SequentialSectionEntryRow.HorizontalScrollMetricsReader(reduceMotion: reduceMotion) { snapshot in
                    if entryScrollSnapshot != snapshot {
                        entryScrollSnapshot = snapshot
                    }
                }
            }
        }
        .allowsHitTesting(isInteractionEnabled)
        .mask {
            HStack(spacing: 0) {
                edgeMask(.leading)
                Rectangle()
                    .fill(.black)
                edgeMask(.trailing)
            }
        }
        .overlay {
            HStack(spacing: 0) {
                edgeFeather(.leading)
                    .opacity(canScrollChipsLeft ? 1 : 0)
                Spacer()
                edgeFeather(.trailing)
                    .opacity(canScrollChipsRight ? 1 : 0)
            }
            .padding(.horizontal, -AppTheme.spacingRegular)
            .allowsHitTesting(false)
        }
    }

    private func edgeFeather(_ edge: HorizontalEdge) -> some View {
        LinearGradient(
            colors: edge == .leading
                ? [palette.background, palette.background.opacity(0)]
                : [palette.background.opacity(0), palette.background],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: SequentialSectionEntryScrollerLayout.edgeFeatherWidth)
    }

    private func edgeMask(_ edge: HorizontalEdge) -> some View {
        if edge == .leading {
            LinearGradient(
                colors: canScrollChipsLeft ? [.clear, .black] : [.black, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: SequentialSectionEntryScrollerLayout.edgeFeatherWidth)
        } else {
            LinearGradient(
                colors: canScrollChipsRight ? [.black, .clear] : [.black, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: SequentialSectionEntryScrollerLayout.edgeFeatherWidth)
        }
    }
}
