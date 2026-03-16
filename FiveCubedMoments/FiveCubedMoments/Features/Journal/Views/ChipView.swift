import SwiftUI

struct ChipView: View {
    let label: String
    let isTruncated: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @AppStorage("confirmChipDeletion") private var confirmChipDeletion = true
    @State private var showDeleteConfirm = false

    private static let chipBackground = AppTheme.complete.opacity(0.2)
    private static let maxLabelWidth: CGFloat = 120

    init(
        label: String,
        isTruncated: Bool,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.label = label
        self.isTruncated = isTruncated
        self.onTap = onTap
        self.onDelete = onDelete
    }

    var body: some View {
        chipContent
            .contentShape(.rect)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard let delete = onDelete else { return }
                if confirmChipDeletion {
                    showDeleteConfirm = true
                } else {
                    delete()
                }
            })
            .contextMenu {
                if onDelete != nil {
                    Button(role: .destructive) {
                        if confirmChipDeletion {
                            showDeleteConfirm = true
                        } else {
                            onDelete?()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Delete") {
                guard onDelete != nil else { return }
                if confirmChipDeletion {
                    showDeleteConfirm = true
                } else {
                    onDelete?()
                }
            }
            .confirmationDialog("Delete \(label)?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    private var chipContent: some View {
        Button(action: onTap) {
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
    }
}
