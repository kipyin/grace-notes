import SwiftUI

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

    init(
        title: String,
        items: [JournalItem],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        inputText: Binding<String>,
        editingIndex: Int?,
        onSubmit: @escaping () -> Void,
        onChipTap: @escaping (Int) -> Void
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
    }

    private var showInput: Bool {
        items.count < slotCount || editingIndex != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // id: \.offset assumes no delete/reorder. If delete is added, switch to stable id (e.g., JournalItem.id or fullText) to avoid view reuse issues.
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            ChipView(
                                label: item.displayLabel,
                                isTruncated: item.isTruncated,
                                onTap: { onChipTap(index) }
                            )
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

            Text("\(items.count) of \(slotCount)")
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
        }
    }
}
