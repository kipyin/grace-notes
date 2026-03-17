import SwiftUI

struct ChipView: View {
    let label: String
    let isTruncated: Bool
    let onTap: () -> Void
    let onRenameLabel: ((String) -> Void)?
    let onDelete: (() -> Void)?

    @State private var showRenamePrompt = false
    @State private var renameDraft = ""

    private static let chipBackground = AppTheme.complete.opacity(0.2)
    private static let maxLabelWidth: CGFloat = 120

    init(
        label: String,
        isTruncated: Bool,
        onTap: @escaping () -> Void,
        onRenameLabel: ((String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.label = label
        self.isTruncated = isTruncated
        self.onTap = onTap
        self.onRenameLabel = onRenameLabel
        self.onDelete = onDelete
    }

    var body: some View {
        chipContent
            .contentShape(.rect)
            .contextMenu {
                if onRenameLabel != nil {
                    Button {
                        beginRename()
                    } label: {
                        Label("Rename label", systemImage: "pencil")
                    }
                }
                if onDelete != nil {
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Delete") {
                guard onDelete != nil else { return }
                onDelete?()
            }
            .accessibilityAction(named: "Rename label") {
                guard onRenameLabel != nil else { return }
                beginRename()
            }
            .alert("Rename label", isPresented: $showRenamePrompt) {
                TextField("Label", text: $renameDraft)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    commitRename()
                }
            } message: {
                Text("This only changes the chip label.")
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

    private func beginRename() {
        renameDraft = label
        showRenamePrompt = true
    }

    private func commitRename() {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRenameLabel?(trimmed)
    }
}
