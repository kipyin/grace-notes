import SwiftUI
import QuartzCore
import UIKit

private struct AddSentenceBrowseChromeModifier: ViewModifier {
    @Environment(\.todayJournalPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppTheme.spacingRegular)
            .padding(.vertical, AppTheme.spacingRegular)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(palette.paper.opacity(0.72 * palette.sectionPaperOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(palette.inputBorder.opacity(0.76), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }
}

private extension View {
    /// Browse-state chrome for the add control (matches `SentenceStripView` row styling).
    func journalAddSentenceBrowseRowChrome() -> some View {
        modifier(AddSentenceBrowseChromeModifier())
    }
}

// UIViewRepresentable coordinator nests deeply; keeping related types together avoids generic module-level names.
// swiftlint:disable type_body_length nesting

/// Namespace for chip-row implementation details used by `SequentialSectionView`.
enum SequentialSectionStripRow {
    struct HorizontalScrollMetrics: Equatable {
        var viewportWidth: CGFloat = 0
        var contentWidth: CGFloat = 0
        var contentOffsetX: CGFloat = 0
    }

    // MARK: - Chip row scroll metrics (elastic stretch disabled; keeps edge masks in sync)

    struct StripRowScrollSnapshot: Equatable {
        var metrics: HorizontalScrollMetrics
        /// Added to 1.0 for `scaleEffect`; kept at zero (no rubber-band scaling).
        var elasticDeltaX: CGFloat
        var elasticDeltaY: CGFloat
    }

    /// Drives `.animation(nil, value:)` so chip-row scale stays non-animated.
    struct StripRowElasticAnimationKey: Equatable {
        var deltaX: CGFloat
        var deltaY: CGFloat
    }

    enum StripRowScrollElasticity {
        static func deltas(
            metrics _: HorizontalScrollMetrics,
            velocityPointsPerSec _: CGFloat,
            isUserDragging _: Bool,
            reduceMotion _: Bool
        ) -> (CGFloat, CGFloat) {
            (0, 0)
        }
    }

    /// Label row used by the add control and by the morph composer slot (same chrome).
    struct AddSentenceRowLabel: View {
        @Environment(\.todayJournalPalette) private var palette
        let title: String
        let showsTrailingChevron: Bool

        var body: some View {
            HStack(spacing: AppTheme.spacingTight) {
                Image(systemName: "plus.circle.fill")
                    .font(AppTheme.outfitRegularTitle3)
                    .foregroundStyle(AppTheme.accentText)
                Text(title)
                .font(AppTheme.warmPaperMetaEmphasis)
                .foregroundStyle(palette.textPrimary)
                if showsTrailingChevron {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.outfitSemiboldCaption)
                        .foregroundStyle(palette.textMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    struct AddStripRowView: View {
        let buttonTitle: String
        let accessibilityHint: String
        /// Stable query for UI tests (`XCUIApplication` matches this as the element identifier).
        let accessibilityIdentifier: String?
        let showsTrailingChevron: Bool
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                AddSentenceRowLabel(title: buttonTitle, showsTrailingChevron: showsTrailingChevron)
                    .journalAddSentenceBrowseRowChrome()
            }
            .buttonStyle(WarmPaperPressStyle())
            .accessibilityLabel(buttonTitle)
            .accessibilityHint(accessibilityHint)
            .modifier(ConditionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
        }
    }

    /// Single slot that morphs between the add control and the composer field (matches strip inline editor layout).
    struct AddSentenceMorphSlot: View {
        let sectionTitle: String
        let addButtonTitle: String
        let addButtonAccessibilityHint: String
        let accessibilityIdentifier: String?
        let showsTrailingChevron: Bool
        let isComposing: Bool
        let placeholder: String
        @Binding var text: String
        let reduceMotion: Bool
        let inputFocus: FocusState<Bool>.Binding?
        let inputAccessibilityIdentifier: String?
        let onAddTap: () -> Void
        let onComposerSubmit: () -> Void
        let isInteractionEnabled: Bool

        @State private var morphingFromAddTap = false

        var body: some View {
            Group {
                if isComposing {
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                        InlineSentenceEditorField(
                            sectionTitle: sectionTitle,
                            placeholder: placeholder,
                            text: $text,
                            editorIdentifier: inputAccessibilityIdentifier,
                            inputFocus: inputFocus,
                            onSubmit: onComposerSubmit,
                            isInteractionEnabled: isInteractionEnabled
                        )
                    }
                    .padding(.horizontal, SequentialSectionInlineLayout.editorMorphHorizontalInset)
                    .offset(
                        y: morphingFromAddTap
                            ? 2
                            : SequentialSectionInlineLayout.editorMorphVerticalOffset
                    )
                    .scaleEffect(
                        x: reduceMotion ? 1 : (morphingFromAddTap ? 1 : 1.02),
                        y: 1,
                        anchor: .center
                    )
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.22),
                        value: morphingFromAddTap
                    )
                    .padding(.bottom, SequentialSectionInlineLayout.editorBottomSpacing)
                    .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
                } else {
                    Button(action: onAddTap) {
                        AddSentenceRowLabel(title: addButtonTitle, showsTrailingChevron: showsTrailingChevron)
                            .journalAddSentenceBrowseRowChrome()
                    }
                    .buttonStyle(WarmPaperPressStyle())
                    .accessibilityLabel(addButtonTitle)
                    .accessibilityHint(addButtonAccessibilityHint)
                    .modifier(ConditionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isComposing)
            .onChange(of: isComposing) { wasComposing, isComposing in
                guard !wasComposing, isComposing else { return }
                morphingFromAddTap = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    morphingFromAddTap = false
                }
            }
        }
    }

    struct ConditionalAccessibilityIdentifier: ViewModifier {
        let identifier: String?
        func body(content: Content) -> some View {
            if let id = identifier {
                content.accessibilityIdentifier(id)
            } else {
                content
            }
        }
    }

    struct HorizontalScrollMetricsReader: UIViewRepresentable {
        let reduceMotion: Bool
        let onChange: (StripRowScrollSnapshot) -> Void

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
            var onChange: (StripRowScrollSnapshot) -> Void
            private var contentSizeObservation: NSKeyValueObservation?
            private var contentOffsetObservation: NSKeyValueObservation?
            private var boundsObservation: NSKeyValueObservation?

            private var lastOffsetX: CGFloat?
            private var lastSampleTime: CFTimeInterval?
            private var smoothedVelocity: CGFloat = 0
            private var isUserDraggingScroll = false
            private var lastPublishedSnapshot: StripRowScrollSnapshot?
            private var pendingPublishWorkItem: DispatchWorkItem?

            init(reduceMotion: Bool, onChange: @escaping (StripRowScrollSnapshot) -> Void) {
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

                let (deltaX, deltaY) = StripRowScrollElasticity.deltas(
                    metrics: metrics,
                    velocityPointsPerSec: smoothedVelocity,
                    isUserDragging: isUserDraggingScroll,
                    reduceMotion: reduceMotion
                )

                let snapshot = StripRowScrollSnapshot(
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

    final class MetricsProbeView: UIView {
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

    struct StripReorderDropDelegate: DropDelegate {
        let targetIndex: Int
        let items: [Entry]
        @Binding var draggingItemID: UUID?
        @Binding var hoverTargetItemID: UUID?
        let reduceMotion: Bool
        let onMoveStrip: ((Int, Int) -> Void)?

        /// Indices for `JournalViewModel.moveItem`-compatible `onMoveStrip`, or nil when no reorder should run.
        static func stripReorderMoveParameters(
            activeDragID: UUID,
            items: [Entry],
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
            guard let onMoveStrip else {
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
               let params = Self.stripReorderMoveParameters(
                   activeDragID: activeDragID,
                   items: items,
                   targetIndex: targetIndex
               ) {
                animateReorder {
                    onMoveStrip(params.source, params.destination)
                }
            }
            return true
        }

        /// Also invoked from unit tests (`DropInfo` is not publicly constructible).
        internal func applyLiveReorderIfNeeded() {
            guard let onMoveStrip, let activeDragID = draggingItemID else { return }
            guard items.indices.contains(targetIndex) else { return }
            let targetItemID = items[targetIndex].id
            if activeDragID == targetItemID {
                hoverTargetItemID = nil
                return
            }
            if hoverTargetItemID == targetItemID { return }
            guard let params = Self.stripReorderMoveParameters(
                activeDragID: activeDragID,
                items: items,
                targetIndex: targetIndex
            ) else { return }

            animateReorder {
                onMoveStrip(params.source, params.destination)
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
}
// swiftlint:enable type_body_length nesting
