import SwiftUI
import QuartzCore
import UIKit

struct HorizontalScrollMetrics: Equatable {
    var viewportWidth: CGFloat = 0
    var contentWidth: CGFloat = 0
    var contentOffsetX: CGFloat = 0
}

// MARK: - Chip row scroll metrics (elastic stretch disabled; keeps edge masks in sync)

struct ChipRowScrollSnapshot: Equatable {
    var metrics: HorizontalScrollMetrics
    /// Added to 1.0 for `scaleEffect`; kept at zero (no rubber-band scaling).
    var elasticDeltaX: CGFloat
    var elasticDeltaY: CGFloat
}

/// Drives `.animation(nil, value:)` so chip-row scale stays non-animated.
struct ChipRowElasticAnimationKey: Equatable {
    var deltaX: CGFloat
    var deltaY: CGFloat
}

enum ChipRowScrollElasticity {
    static func deltas(
        metrics _: HorizontalScrollMetrics,
        velocityPointsPerSec _: CGFloat,
        isUserDragging _: Bool,
        reduceMotion _: Bool
    ) -> (CGFloat, CGFloat) {
        (0, 0)
    }
}

struct AddChipView: View {
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
