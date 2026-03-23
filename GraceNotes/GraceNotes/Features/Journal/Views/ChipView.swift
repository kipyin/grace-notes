import SwiftUI

struct ChipView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let label: String
    let isTruncated: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onRenameLabel: ((String) -> Void)?
    let onDelete: (() -> Void)?

    @State private var showRenamePrompt = false
    @State private var renameDraft = ""

    private static let chipBackground = AppTheme.journalComplete.opacity(0.2)

    private var resolvedMaxLabelWidth: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 220
        }
        if isTruncated {
            return 140
        }
        return 170
    }

    init(
        label: String,
        isTruncated: Bool,
        isSelected: Bool = false,
        onTap: @escaping () -> Void,
        onRenameLabel: ((String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.label = label
        self.isTruncated = isTruncated
        self.isSelected = isSelected
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
                        Label(String(localized: "Rename label"), systemImage: "pencil")
                    }
                }
                if onDelete != nil {
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label(String(localized: "Delete"), systemImage: "trash")
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text(String(localized: "Delete"))) {
                guard onDelete != nil else { return }
                onDelete?()
            }
            .accessibilityAction(named: Text(String(localized: "Rename label"))) {
                guard onRenameLabel != nil else { return }
                beginRename()
            }
            .alert(String(localized: "Rename label"), isPresented: $showRenamePrompt) {
                TextField(String(localized: "Label"), text: $renameDraft)
                    .font(AppTheme.outfitUI)
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Save")) {
                    commitRename()
                }
            } message: {
                Text(String(localized: "This only changes the short label."))
            }
    }

    private var chipContent: some View {
        Button(action: onTap) {
            Text(label)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.journalTextPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, AppTheme.spacingRegular)
                .padding(.vertical, AppTheme.spacingTight)
                .frame(minWidth: 44, minHeight: 44)
                .frame(maxWidth: resolvedMaxLabelWidth, alignment: .leading)
                .background(isSelected ? AppTheme.journalActiveEditingAccent.opacity(0.28) : Self.chipBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(
                            isSelected ? AppTheme.journalActiveEditingAccentStrong.opacity(0.86) : .clear,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                .mask(
                    Group {
                        if isTruncated {
                            LinearGradient(
                                stops: [
                                    .init(color: AppTheme.journalTextPrimary, location: 0),
                                    .init(color: AppTheme.journalTextPrimary, location: 0.82),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            AppTheme.journalTextPrimary
                        }
                    }
                )
        }
        .buttonStyle(WarmPaperPressStyle())
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
