import SwiftUI

private struct AddChipView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.complete.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add new")
    }
}

private struct ConditionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let id = identifier {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

struct SequentialSectionView: View {
    let title: String
    let items: [JournalItem]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    @Binding var inputText: String
    let editingIndex: Int?
    let onSubmit: () -> Void
    let onChipTap: (Int) -> Void
    let onDeleteChip: ((Int) -> Void)?
    let onAddNew: (() -> Void)?

    init(
        title: String,
        items: [JournalItem],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        inputText: Binding<String>,
        editingIndex: Int?,
        onSubmit: @escaping () -> Void,
        onChipTap: @escaping (Int) -> Void,
        onDeleteChip: ((Int) -> Void)? = nil,
        onAddNew: (() -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.placeholder = placeholder
        self.slotCount = slotCount
        self.inputAccessibilityIdentifier = inputAccessibilityIdentifier
        self._inputText = inputText
        self.editingIndex = editingIndex
        self.onSubmit = onSubmit
        self.onChipTap = onChipTap
        self.onDeleteChip = onDeleteChip
        self.onAddNew = onAddNew
    }

    private var showInput: Bool {
        items.count < slotCount || editingIndex != nil
    }

    private var progressText: String {
        let formatKey = String(localized: "%d of %d")
        let currentSlot: Int
        if let idx = editingIndex {
            currentSlot = idx + 1
        } else {
            currentSlot = min(items.count + 1, slotCount)
        }
        return String(format: formatKey, currentSlot, slotCount)
    }

    private var showAddChip: Bool {
        guard onAddNew != nil, !items.isEmpty else { return false }
        return editingIndex != nil || items.count < slotCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            if !items.isEmpty || showAddChip {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            ChipView(
                                label: item.displayLabel,
                                isTruncated: item.isTruncated,
                                onTap: { onChipTap(index) },
                                onDelete: onDeleteChip.map { handler in { handler(index) } }
                            )
                        }
                        if showAddChip, let addNew = onAddNew {
                            AddChipView(onTap: addNew)
                        }
                    }
                }
            }

            if showInput {
                TextField(placeholder, text: $inputText)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit { onSubmit() }
                    .warmPaperInputStyle()
                    .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
            }

            Text(progressText)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
        }
    }
}
