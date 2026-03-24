import SwiftUI
import QuartzCore
import UniformTypeIdentifiers
import UIKit

private struct HorizontalScrollMetrics: Equatable {
    var viewportWidth: CGFloat = 0
    var contentWidth: CGFloat = 0
    var contentOffsetX: CGFloat = 0
}

// MARK: - Chip row scroll metrics (elastic stretch disabled; keeps edge masks in sync)

private struct ChipRowScrollSnapshot: Equatable {
    var metrics: HorizontalScrollMetrics
    /// Added to 1.0 for `scaleEffect`; kept at zero (no rubber-band scaling).
    var elasticDeltaX: CGFloat
    var elasticDeltaY: CGFloat
}

/// Drives `.animation(nil, value:)` so chip-row scale stays non-animated.
private struct ChipRowElasticAnimationKey: Equatable {
    var deltaX: CGFloat
    var deltaY: CGFloat
}

private enum ChipRowScrollElasticity {
    static func deltas(
        metrics _: HorizontalScrollMetrics,
        velocityPointsPerSec _: CGFloat,
        isUserDragging _: Bool,
        reduceMotion _: Bool
    ) -> (CGFloat, CGFloat) {
        (0, 0)
    }
}

private struct AddChipView: View {
    let sectionTitle: String
    /// Stable query for UI tests (`XCUIApplication` matches this as the element identifier).
    let accessibilityIdentifier: String?
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
        .modifier(ConditionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
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

// swiftlint:disable type_body_length
struct SequentialSectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum SlotStatus {
        case edited
        case editing
        case pending
    }

    let title: String
    /// Guided onboarding title shown above the section header (e.g. “Start gently”).
    let guidanceTitle: String?
    /// Guided onboarding message shown under `guidanceTitle`.
    let guidanceMessage: String?
    /// Optional second line under `guidanceMessage` (e.g. keyboard hint).
    let guidanceMessageSecondary: String?
    let items: [JournalItem]
    let placeholder: String
    let slotCount: Int
    let inputAccessibilityIdentifier: String?
    /// When set (e.g. UI tests), chips use identifiers `"\(prefix).\(index)"` for stable XCUITest queries.
    let chipAccessibilityIdentifierPrefix: String?
    /// When set (e.g. UI tests), the section (+) control exposes this `accessibilityIdentifier`.
    let addChipAccessibilityIdentifier: String?
    let onboardingState: JournalOnboardingSectionState
    let isTransitioning: Bool
    @Binding var inputText: String
    let editingIndex: Int?
    let inputFocus: FocusState<Bool>.Binding?
    /// Fires when the chip field loses focus; handler ignores empty drafts.
    let onInputFocusLost: (() -> Void)?
    let onSubmit: () -> Void
    let onChipTap: (Int) -> Void
    let onRenameChip: ((Int, String) -> Void)?
    let onMoveChip: ((Int, Int) -> Void)?
    let onDeleteChip: ((Int) -> Void)?
    let onAddNew: (() -> Void)?
    private static let edgeFeatherWidth: CGFloat = 28
    private static let sectionProgressDotsTrailingInset: CGFloat = 8
    @State private var draggingItemID: UUID?
    /// Chip UUID that last triggered a live reorder during this drag.
    /// Skips redundant `dropUpdated` work when indices shift but the finger stays on the same chip.
    @State private var chipReorderHoverTargetItemID: UUID?
    @State private var chipScrollSnapshot = ChipRowScrollSnapshot(
        metrics: HorizontalScrollMetrics(),
        elasticDeltaX: 0,
        elasticDeltaY: 0
    )
    @State private var isEditingPulseExpanded = false

    init(
        title: String,
        guidanceTitle: String? = nil,
        guidanceMessage: String? = nil,
        guidanceMessageSecondary: String? = nil,
        items: [JournalItem],
        placeholder: String,
        slotCount: Int = 5,
        inputAccessibilityIdentifier: String? = nil,
        chipAccessibilityIdentifierPrefix: String? = nil,
        addChipAccessibilityIdentifier: String? = nil,
        onboardingState: JournalOnboardingSectionState = .standard,
        isTransitioning: Bool = false,
        inputText: Binding<String>,
        editingIndex: Int?,
        inputFocus: FocusState<Bool>.Binding? = nil,
        onInputFocusLost: (() -> Void)? = nil,
        onSubmit: @escaping () -> Void,
        onChipTap: @escaping (Int) -> Void,
        onRenameChip: ((Int, String) -> Void)? = nil,
        onMoveChip: ((Int, Int) -> Void)? = nil,
        onDeleteChip: ((Int) -> Void)? = nil,
        onAddNew: (() -> Void)? = nil
    ) {
        self.title = title
        self.guidanceTitle = guidanceTitle
        self.guidanceMessage = guidanceMessage
        self.guidanceMessageSecondary = guidanceMessageSecondary
        self.items = items
        self.placeholder = placeholder
        self.slotCount = slotCount
        self.inputAccessibilityIdentifier = inputAccessibilityIdentifier
        self.chipAccessibilityIdentifierPrefix = chipAccessibilityIdentifierPrefix
        self.addChipAccessibilityIdentifier = addChipAccessibilityIdentifier
        self.onboardingState = onboardingState
        self.isTransitioning = isTransitioning
        self._inputText = inputText
        self.editingIndex = editingIndex
        self.inputFocus = inputFocus
        self.onInputFocusLost = onInputFocusLost
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

    private var isLockedByGuidance: Bool {
        onboardingState.isLocked
    }

    private var isInteractionEnabled: Bool {
        !isTransitioning && !isLockedByGuidance
    }

    private var canScrollChipsLeft: Bool {
        canScrollLeft(for: chipScrollSnapshot.metrics)
    }

    private var canScrollChipsRight: Bool {
        canScrollRight(for: chipScrollSnapshot.metrics)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                if let guidanceTitle, let guidanceMessage {
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                        Text(guidanceTitle)
                            .font(AppTheme.warmPaperMetaEmphasis)
                            .foregroundStyle(AppTheme.accentText)
                        Text(guidanceMessage)
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.journalTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let guidanceMessageSecondary {
                            Text(guidanceMessageSecondary)
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.journalTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let guidanceNote = onboardingState.guidanceNote {
                    Text(guidanceNote)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.journalTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(title)
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(onboardingState.titleColor)
                    Spacer(minLength: AppTheme.spacingTight)
                    sectionProgressDots
                        .padding(.trailing, Self.sectionProgressDotsTrailingInset)
                }
            }

            if !items.isEmpty || showAddChip {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingTight) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            chipView(for: item, at: index)
                        }
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
                        .disabled(!isInteractionEnabled)
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
                        .disabled(!isInteractionEnabled)
                }
            }

        }
        .journalOnboardingSectionStyle(onboardingState, isTransitioning: isTransitioning)
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
        .onChange(of: isInputFocused) { wasFocused, isFocused in
            guard let onInputFocusLost else { return }
            if wasFocused, !isFocused {
                onInputFocusLost()
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
        let chipIdentifier = chipAccessibilityIdentifierPrefix.map { "\($0).\(index)" }
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
                .modifier(ConditionalAccessibilityIdentifier(identifier: chipIdentifier))
                .onDrag {
                    chipReorderHoverTargetItemID = nil
                    draggingItemID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                } preview: {
                    chip
                        .scaleEffect(reduceMotion ? 1 : 1.07)
                        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ChipReorderDropDelegate(
                        targetIndex: index,
                        items: items,
                        draggingItemID: $draggingItemID,
                        hoverTargetItemID: $chipReorderHoverTargetItemID,
                        reduceMotion: reduceMotion,
                        onMoveChip: onMoveChip
                    )
                )
        } else {
            chip
                .modifier(ConditionalAccessibilityIdentifier(identifier: chipIdentifier))
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

// swiftlint:enable type_body_length

private struct HorizontalScrollMetricsReader: UIViewRepresentable {
    let reduceMotion: Bool
    let onChange: (ChipRowScrollSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(reduceMotion: reduceMotion, onChange: onChange)
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
        context.coordinator.reduceMotion = reduceMotion
        context.coordinator.onChange = onChange
        context.coordinator.attachIfPossible()
    }

    final class Coordinator: NSObject {
        weak var hostView: UIView?
        weak var observedScrollView: UIScrollView?
        var reduceMotion: Bool
        var onChange: (ChipRowScrollSnapshot) -> Void
        private var contentSizeObservation: NSKeyValueObservation?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var boundsObservation: NSKeyValueObservation?

        private var lastOffsetX: CGFloat?
        private var lastSampleTime: CFTimeInterval?
        private var smoothedVelocity: CGFloat = 0
        private var isUserDraggingScroll = false
        private var lastPublishedSnapshot: ChipRowScrollSnapshot?
        private var pendingPublishWorkItem: DispatchWorkItem?

        init(reduceMotion: Bool, onChange: @escaping (ChipRowScrollSnapshot) -> Void) {
            self.reduceMotion = reduceMotion
            self.onChange = onChange
        }

        deinit {
            detachPanTarget()
        }

        func attachIfPossible() {
            guard let hostView else { return }
            guard let scrollView = findAncestorScrollView(from: hostView) else { return }
            if observedScrollView === scrollView {
                publishSnapshot()
                return
            }

            detachPanTarget()
            tearDownObservations()

            lastOffsetX = nil
            lastSampleTime = nil
            smoothedVelocity = 0
            isUserDraggingScroll = false
            lastPublishedSnapshot = nil
            pendingPublishWorkItem?.cancel()
            pendingPublishWorkItem = nil

            observedScrollView = scrollView
            scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))

            contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                self?.publishSnapshot()
            }
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                self?.publishSnapshot()
            }
            boundsObservation = scrollView.observe(\.bounds, options: [.new]) { [weak self] _, _ in
                self?.publishSnapshot()
            }
            publishSnapshot()
        }

        private func tearDownObservations() {
            contentSizeObservation = nil
            contentOffsetObservation = nil
            boundsObservation = nil
            lastPublishedSnapshot = nil
            pendingPublishWorkItem?.cancel()
            pendingPublishWorkItem = nil
        }

        private func detachPanTarget() {
            observedScrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePan(_:)))
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                isUserDraggingScroll = true
                publishSnapshot()
            case .changed:
                isUserDraggingScroll = true
            case .ended, .cancelled, .failed:
                isUserDraggingScroll = false
                smoothedVelocity = 0
                lastOffsetX = nil
                lastSampleTime = nil
                publishSnapshot()
            default:
                break
            }
        }

        private func publishSnapshot() {
            guard let scrollView = observedScrollView else { return }

            let metrics = HorizontalScrollMetrics(
                viewportWidth: scrollView.bounds.width,
                contentWidth: scrollView.contentSize.width,
                contentOffsetX: scrollView.contentOffset.x
            )

            let now = CACurrentMediaTime()
            if let previousX = lastOffsetX, let previousTime = lastSampleTime, now > previousTime {
                let deltaTime = CGFloat(now - previousTime)
                if deltaTime > 0.000001 {
                    let instantVelocity = (metrics.contentOffsetX - previousX) / deltaTime
                    smoothedVelocity = smoothedVelocity * 0.82 + instantVelocity * 0.18
                }
            }
            lastOffsetX = metrics.contentOffsetX
            lastSampleTime = now

            let (deltaX, deltaY) = ChipRowScrollElasticity.deltas(
                metrics: metrics,
                velocityPointsPerSec: smoothedVelocity,
                isUserDragging: isUserDraggingScroll,
                reduceMotion: reduceMotion
            )

            let snapshot = ChipRowScrollSnapshot(
                metrics: metrics,
                elasticDeltaX: deltaX,
                elasticDeltaY: deltaY
            )
            guard snapshot != lastPublishedSnapshot else { return }
            lastPublishedSnapshot = snapshot
            // KVO / layout can invoke this during SwiftUI view updates; async avoids
            // "Modifying state during view update" when the callback touches @State.
            pendingPublishWorkItem?.cancel()
            let callback = onChange
            let workItem = DispatchWorkItem {
                callback(snapshot)
            }
            pendingPublishWorkItem = workItem
            DispatchQueue.main.async(execute: workItem)
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
    @Binding var hoverTargetItemID: UUID?
    let reduceMotion: Bool
    let onMoveChip: ((Int, Int) -> Void)?

    /// Indices for `JournalViewModel.moveItem`-compatible `onMoveChip`, or nil when no reorder should run.
    static func chipReorderMoveParameters(
        activeDragID: UUID,
        items: [JournalItem],
        targetIndex: Int
    ) -> (source: Int, destination: Int)? {
        guard items.indices.contains(targetIndex) else { return nil }
        guard let sourceIndex = items.firstIndex(where: { $0.id == activeDragID }) else { return nil }
        guard sourceIndex != targetIndex else { return nil }
        let destinationOffset = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
        let noOpOffset = sourceIndex + 1
        guard destinationOffset != sourceIndex, destinationOffset != noOpOffset else { return nil }
        return (sourceIndex, destinationOffset)
    }

    func dropEntered(info: DropInfo) {
        applyLiveReorderIfNeeded()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        applyLiveReorderIfNeeded()
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        performDrop()
    }

    func performDrop() -> Bool {
        guard let activeDragID = draggingItemID else { return false }
        guard let onMoveChip else {
            clearDraggingState()
            return false
        }
        guard items.indices.contains(targetIndex) else {
            clearDraggingState()
            return false
        }
        guard items.contains(where: { $0.id == activeDragID }) else {
            clearDraggingState()
            return false
        }
        let targetItemID = items[targetIndex].id
        let liveAlreadyAppliedForThisTarget = hoverTargetItemID == targetItemID
        defer { clearDraggingState() }
        if !liveAlreadyAppliedForThisTarget,
           let params = Self.chipReorderMoveParameters(
               activeDragID: activeDragID,
               items: items,
               targetIndex: targetIndex
           ) {
            animateReorder {
                onMoveChip(params.source, params.destination)
            }
        }
        return true
    }

    /// Also invoked from unit tests (`DropInfo` is not publicly constructible).
    internal func applyLiveReorderIfNeeded() {
        guard let onMoveChip, let activeDragID = draggingItemID else { return }
        guard items.indices.contains(targetIndex) else { return }
        let targetItemID = items[targetIndex].id
        if activeDragID == targetItemID {
            hoverTargetItemID = nil
            return
        }
        if hoverTargetItemID == targetItemID { return }
        guard let params = Self.chipReorderMoveParameters(
            activeDragID: activeDragID,
            items: items,
            targetIndex: targetIndex
        ) else { return }

        animateReorder {
            onMoveChip(params.source, params.destination)
        }
        hoverTargetItemID = targetItemID
    }

    private func animateReorder(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.snappy(duration: 0.28)) {
                updates()
            }
        }
    }

    private func clearDraggingState() {
        draggingItemID = nil
        hoverTargetItemID = nil
    }
}
