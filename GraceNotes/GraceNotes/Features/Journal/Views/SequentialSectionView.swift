import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct AddChipView: View {
    let sectionTitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus.circle.fill")
                .font(AppTheme.outfitRegularTitle3)
                .foregroundStyle(AppTheme.journalTextMuted)
                .padding(.horizontal, AppTheme.spacingRegular)
                .padding(.vertical, AppTheme.spacingTight)
                .frame(minWidth: 44, minHeight: 44)
                .background(AppTheme.journalComplete.opacity(0.2))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum SlotStatus {
        case edited
        case editing
        case pending
    }

    let title: String
    let items: [JournalItem]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    let isTransitioning: Bool
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
    private static let sectionProgressDotsTrailingInset: CGFloat = 8
    @State private var draggingItemID: UUID?
    @State private var chipScrollMetrics = HorizontalScrollMetrics()
    @State private var isEditingPulseExpanded = false

    init(
        title: String,
        items: [JournalItem],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        isTransitioning: Bool = false,
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
        self.isTransitioning = isTransitioning
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

    private var isInputFocused: Bool {
        inputFocus?.wrappedValue ?? false
    }

    private var shouldAnimateEditingPulse: Bool {
        isInputFocused && !reduceMotion
    }

    private var slotStatuses: [SlotStatus] {
        (0..<slotCount).map { index in
            if editingIndex == index {
                return .editing
            }
            if index < items.count {
                return .edited
            }
            return .pending
        }
    }

    private var progressAccessibilityLabel: String {
        let editedCount = slotStatuses.filter { $0 == .edited }.count
        let editingCount = slotStatuses.filter { $0 == .editing }.count
        let pendingCount = slotStatuses.filter { $0 == .pending }.count
        return String(
            format: String(localized: "%1$@ progress. %2$d complete, %3$d in progress, %4$d open."),
            locale: Locale.current,
            title,
            editedCount,
            editingCount,
            pendingCount
        )
    }

    private var inputAccessibilityLabel: String {
        String(
            format: String(localized: "%@ input"),
            locale: Locale.current,
            title
        )
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
                    .foregroundStyle(AppTheme.journalTextPrimary)
                Spacer(minLength: AppTheme.spacingTight)
                sectionProgressDots
                    .padding(.trailing, Self.sectionProgressDotsTrailingInset)
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
                .allowsHitTesting(!isTransitioning)
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
                    TextField(
                        "",
                        text: $inputText,
                        prompt: Text(placeholder)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.journalInputPlaceholder)
                    )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.journalTextPrimary)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { onSubmit() }
                        .focused(inputFocus)
                        .warmPaperInputStyle()
                        .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
                        .accessibilityLabel(inputAccessibilityLabel)
                        .accessibilityHint(placeholder)
                        .disabled(isTransitioning)
                } else {
                    TextField(
                        "",
                        text: $inputText,
                        prompt: Text(placeholder)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.journalInputPlaceholder)
                    )
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.journalTextPrimary)
                        .textInputAutocapitalization(.sentences)
                        .onSubmit { onSubmit() }
                        .warmPaperInputStyle()
                        .modifier(ConditionalAccessibilityIdentifier(identifier: inputAccessibilityIdentifier))
                        .accessibilityLabel(inputAccessibilityLabel)
                        .accessibilityHint(placeholder)
                        .disabled(isTransitioning)
                }
            }

        }
        .opacity(isTransitioning ? 0.78 : 1)
        .overlay(alignment: .topTrailing) {
            if isTransitioning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(localized: "Updating…"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.journalTextMuted)
                }
                .padding(.horizontal, AppTheme.spacingTight)
                .padding(.vertical, 6)
                .background(AppTheme.journalPaper.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.journalInputBorder.opacity(0.7), lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(
                        format: String(localized: "%@ section is updating."),
                        locale: Locale.current,
                        title
                    )
                )
            }
        }
        .onAppear {
            updateEditingPulseAnimation()
        }
        .onChange(of: shouldAnimateEditingPulse) { _, _ in
            updateEditingPulseAnimation()
        }
    }

    private var sectionProgressDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(slotStatuses.enumerated()), id: \.offset) { _, status in
                Circle()
                    .fill(dotFill(for: status))
                    .frame(width: dotDiameter(for: status), height: dotDiameter(for: status))
                    .overlay(
                        Circle()
                            .stroke(dotBorder(for: status), lineWidth: dotBorderWidth(for: status))
                    )
                    .overlay {
                        if status == .editing {
                            Circle()
                                .fill(AppTheme.journalActiveEditingAccentStrong)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .overlay {
                        if status == .editing && shouldAnimateEditingPulse {
                            Circle()
                                .stroke(AppTheme.journalActiveEditingAccentStrong.opacity(0.45), lineWidth: 1)
                                .frame(width: 14, height: 14)
                                .scaleEffect(isEditingPulseExpanded ? 1.14 : 0.94)
                                .opacity(isEditingPulseExpanded ? 0 : 0.56)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressAccessibilityLabel)
    }

    private func dotFill(for status: SlotStatus) -> Color {
        switch status {
        case .edited:
            return AppTheme.journalComplete
        case .editing:
            return AppTheme.journalActiveEditingAccent.opacity(0.28)
        case .pending:
            return .clear
        }
    }

    private func dotBorder(for status: SlotStatus) -> Color {
        switch status {
        case .edited:
            return .clear
        case .editing:
            return AppTheme.journalActiveEditingAccentStrong.opacity(0.9)
        case .pending:
            return AppTheme.journalPendingOutline.opacity(0.52)
        }
    }

    private func dotBorderWidth(for status: SlotStatus) -> CGFloat {
        switch status {
        case .edited:
            return 0
        case .editing:
            return 1.2
        case .pending:
            return 1
        }
    }

    private func dotDiameter(for status: SlotStatus) -> CGFloat {
        status == .editing ? 11.5 : 10
    }

    private func updateEditingPulseAnimation() {
        guard shouldAnimateEditingPulse else {
            isEditingPulseExpanded = false
            return
        }

        isEditingPulseExpanded = false
        withAnimation(.easeOut(duration: 0.82).repeatForever(autoreverses: false)) {
            isEditingPulseExpanded = true
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
