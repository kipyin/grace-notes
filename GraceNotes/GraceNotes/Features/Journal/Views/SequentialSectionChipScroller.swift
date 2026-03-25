import SwiftUI

/// Horizontal chip row with scroll metrics, masks, and optional add control.
struct SequentialSectionChipScroller<ChipRow: View>: View {
    let reduceMotion: Bool
    let title: String
    let showAddChip: Bool
    let addChipAccessibilityIdentifier: String?
    let isInteractionEnabled: Bool
    let canScrollChipsLeft: Bool
    let canScrollChipsRight: Bool
    let onAddNew: (() -> Void)?

    @Binding var chipScrollSnapshot: ChipRowScrollSnapshot

    @ViewBuilder var chipRow: () -> ChipRow

    private static let edgeFeatherWidth: CGFloat = 28

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingTight) {
                chipRow()
                if showAddChip, let addNew = onAddNew {
                    AddChipView(
                        sectionTitle: title,
                        accessibilityIdentifier: addChipAccessibilityIdentifier,
                        onTap: addNew
                    )
                }
            }
            .padding(.trailing, AppTheme.spacingRegular)
            .scaleEffect(
                x: 1 + chipScrollSnapshot.elasticDeltaX,
                y: 1 + chipScrollSnapshot.elasticDeltaY,
                anchor: .center
            )
            .animation(
                nil,
                value: ChipRowElasticAnimationKey(
                    deltaX: chipScrollSnapshot.elasticDeltaX,
                    deltaY: chipScrollSnapshot.elasticDeltaY
                )
            )
            .background {
                HorizontalScrollMetricsReader(reduceMotion: reduceMotion) { snapshot in
                    if chipScrollSnapshot != snapshot {
                        chipScrollSnapshot = snapshot
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
                ? [AppTheme.journalBackground, AppTheme.journalBackground.opacity(0)]
                : [AppTheme.journalBackground.opacity(0), AppTheme.journalBackground],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: Self.edgeFeatherWidth)
    }

    private func edgeMask(_ edge: HorizontalEdge) -> some View {
        if edge == .leading {
            LinearGradient(
                colors: canScrollChipsLeft ? [.clear, .black] : [.black, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.edgeFeatherWidth)
        } else {
            LinearGradient(
                colors: canScrollChipsRight ? [.black, .clear] : [.black, .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: Self.edgeFeatherWidth)
        }
    }
}
