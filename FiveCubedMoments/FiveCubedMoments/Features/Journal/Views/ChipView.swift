import SwiftUI

struct ChipView: View {
    let label: String
    let isTruncated: Bool
    let isDeletionMode: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    let onEnterDeletionMode: () -> Void
    let onExitDeletionMode: () -> Void

    private static let chipBackground = AppTheme.complete.opacity(0.2)
    private static let maxLabelWidth: CGFloat = 120

    init(
        label: String,
        isTruncated: Bool,
        isDeletionMode: Bool,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onEnterDeletionMode: @escaping () -> Void,
        onExitDeletionMode: @escaping () -> Void
    ) {
        self.label = label
        self.isTruncated = isTruncated
        self.isDeletionMode = isDeletionMode
        self.onTap = onTap
        self.onDelete = onDelete
        self.onEnterDeletionMode = onEnterDeletionMode
        self.onExitDeletionMode = onExitDeletionMode
    }

    private var showBadge: Bool {
        isDeletionMode && onDelete != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: chipTapped) {
                Text(label)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: isTruncated ? Self.maxLabelWidth : nil, alignment: .leading)
                    .background(Self.chipBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .mask(
                        Group {
                            if isTruncated {
                                LinearGradient(
                                    colors: [.white, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.white
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
            .contentShape(.rect)
            .wiggle(isActive: showBadge)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if onDelete != nil { onEnterDeletionMode() }
            })
            .highPriorityGesture(
                TapGesture(count: 2).onEnded { _ in
                    if onDelete != nil { onEnterDeletionMode() }
                }
            )

            if showBadge, let delete = onDelete {
                Button {
                    delete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
    }

    private func chipTapped() {
        if isDeletionMode {
            onExitDeletionMode()
        }
        onTap()
    }
}
