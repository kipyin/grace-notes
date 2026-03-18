import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct AddChipView: View {
    let sectionTitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.horizontal, AppTheme.spacingRegular)
                .padding(.vertical, AppTheme.spacingTight)
                .frame(minWidth: 44, minHeight: 44)
                .background(AppTheme.complete.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        }
        .buttonStyle(WarmPaperPressStyle())
        .accessibilityLabel(
            String(
                format: String(localized: "Add new item in %@"),
                locale: Locale.current,
                sectionTitle
            )
        )
        .accessibilityHint(
            String(
                format: String(localized: "Adds another item in %@"),
                locale: Locale.current,
                sectionTitle
            )
        )
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
    let inputFocus: FocusState<Bool>.Binding?
    let onSubmit: () -> Void
    let onChipTap: (Int) -> Void
    let onRenameChip: ((Int, String) -> Void)?
    let onMoveChip: ((Int, Int) -> Void)?
    let onDeleteChip: ((Int) -> Void)?
    let onAddNew: (() -> Void)?
    private static let edgeFeatherWidth: CGFloat = 28
    @State private var draggingItemID: UUID?
    @State private var chipScrollMetrics = HorizontalScrollMetrics()

    init(
        title: String,
        items: [JournalItem],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        inputText: Binding<String>,
        editingIndex: Int?,
        inputFocus: FocusState<Bool>.Binding? = nil,
        onSubmit: @escaping () -> Void,
        onChipTap: @escaping (Int) -> Void,
        onRenameChip: ((Int, String) -> Void)? = nil,
        onMoveChip: ((Int, Int) -> Void)? = nil,
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
        self.inputFocus = inputFocus
        self.onSubmit = onSubmit
        self.onChipTap = onChipTap
        self.onRenameChip = onRenameChip
        self.onMoveChip = onMoveChip
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
        return items.count < slotCount
    }

    private var canScrollChipsLeft: Bool {
        canScrollLeft(for: chipScrollMetrics)
    }

    private var canScrollChipsRight: Bool {
        canScrollRight(for: chipScrollMetrics)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            HStack {
                Text(title)
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: AppTheme.spacingTight)
            }

            if !items.isEmpty || showAddChip {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingTight) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            chipView(for: item, at: index)
                        }
                        if showAddChip, let addNew = onAddNew {
                            AddChipView(sectionTitle: title, onTap: addNew)
                        }
                    }
                    .padding(.trailing, AppTheme.spacingRegular)
                    .background {
                        HorizontalScrollMetricsReader { metrics in
                            let currentMetrics = chipScrollMetrics
                            if currentMetrics != metrics {
                                chipScrollMetrics = metrics
                            }
                        }
                    }
                }
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

            if showInput {
                if let inputFocus {
                    TextField(placeholder, text: $inputText)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { onSubmit() }
                        .focused(inputFocus)
                        .warmPaperInputStyle()
                        .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
                } else {
                    TextField(placeholder, text: $inputText)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { onSubmit() }
                        .warmPaperInputStyle()
                        .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
                }
            }

            Text(progressText)
                .font(AppTheme.warmPaperMetaEmphasis)
                .foregroundStyle(AppTheme.textMuted)
                .monospacedDigit()
                .padding(.top, AppTheme.spacingTight)
        }
    }

    @ViewBuilder
    private func chipView(for item: JournalItem, at index: Int) -> some View {
        let chip = ChipView(
            label: item.displayLabel,
            isTruncated: item.isTruncated,
            isSelected: editingIndex == index,
            onTap: { onChipTap(index) },
            onRenameLabel: onRenameChip.map { handler in { handler(index, $0) } },
            onDelete: onDeleteChip.map { handler in { handler(index) } }
        )

        if let onMoveChip {
            chip
                .onDrag {
                    draggingItemID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ChipReorderDropDelegate(
                        targetIndex: index,
                        items: items,
                        draggingItemID: $draggingItemID,
                        onMoveChip: onMoveChip
                    )
                )
        } else {
            chip
        }
    }

    private func edgeFeather(_ edge: HorizontalEdge) -> some View {
        LinearGradient(
            colors: edge == .leading
                ? [AppTheme.background, AppTheme.background.opacity(0)]
                : [AppTheme.background.opacity(0), AppTheme.background],
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

    private func canScrollLeft(for metrics: HorizontalScrollMetrics) -> Bool {
        metrics.contentOffsetX > 1
    }

    private func canScrollRight(for metrics: HorizontalScrollMetrics) -> Bool {
        let remaining = metrics.contentWidth - (metrics.contentOffsetX + metrics.viewportWidth)
        return remaining > 1
    }
}

private struct HorizontalScrollMetrics: Equatable {
    var viewportWidth: CGFloat = 0
    var contentWidth: CGFloat = 0
    var contentOffsetX: CGFloat = 0
}

private struct HorizontalScrollMetricsReader: UIViewRepresentable {
    let onChange: (HorizontalScrollMetrics) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = MetricsProbeView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.hostView = view
        view.onLayoutChange = { [weak coordinator = context.coordinator] in
            coordinator?.attachIfPossible()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.attachIfPossible()
    }

    final class Coordinator: NSObject {
        weak var hostView: UIView?
        weak var observedScrollView: UIScrollView?
        var onChange: (HorizontalScrollMetrics) -> Void
        private var contentSizeObservation: NSKeyValueObservation?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var boundsObservation: NSKeyValueObservation?

        init(onChange: @escaping (HorizontalScrollMetrics) -> Void) {
            self.onChange = onChange
        }

        func attachIfPossible() {
            guard let hostView else { return }
            guard let scrollView = findAncestorScrollView(from: hostView) else { return }
            guard observedScrollView !== scrollView else {
                publishMetrics()
                return
            }

            observedScrollView = scrollView
            contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                self?.publishMetrics()
            }
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                self?.publishMetrics()
            }
            boundsObservation = scrollView.observe(\.bounds, options: [.new]) { [weak self] _, _ in
                self?.publishMetrics()
            }
            publishMetrics()
        }

        private func publishMetrics() {
            guard let scrollView = observedScrollView else { return }
            onChange(
                HorizontalScrollMetrics(
                    viewportWidth: scrollView.bounds.width,
                    contentWidth: scrollView.contentSize.width,
                    contentOffsetX: scrollView.contentOffset.x
                )
            )
        }

        private func findAncestorScrollView(from view: UIView) -> UIScrollView? {
            var currentView: UIView? = view
            while let candidate = currentView?.superview {
                if let scrollView = candidate as? UIScrollView {
                    return scrollView
                }
                currentView = candidate
            }
            return nil
        }
    }
}

private final class MetricsProbeView: UIView {
    var onLayoutChange: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onLayoutChange?()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        onLayoutChange?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutChange?()
    }
}

struct ChipReorderDropDelegate: DropDelegate {
    let targetIndex: Int
    let items: [JournalItem]
    @Binding var draggingItemID: UUID?
    let onMoveChip: ((Int, Int) -> Void)?

    func dropEntered(info: DropInfo) {
        dropEntered()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dropUpdated()
    }

    func performDrop(info: DropInfo) -> Bool {
        performDrop()
    }

    func dropEntered() {
        // Intentionally no-op: apply reorder only on successful drop.
    }

    func dropUpdated() -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop() -> Bool {
        guard let draggingItemID else { return false }
        defer { self.draggingItemID = nil }
        guard let onMoveChip else { return false }
        guard let sourceIndex = items.firstIndex(where: { $0.id == draggingItemID }) else { return false }
        guard sourceIndex != targetIndex else { return true }

        let destinationOffset = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        onMoveChip(sourceIndex, destinationOffset)
        return true
    }
}
