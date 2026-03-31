import SwiftUI
import UIKit
import AVFoundation

/// Shared seam: looping **bundled** video leaves (`SummerLeavesLoop.mp4`) above the paper field, below content.
/// There is no Canvas/native fallback—without the asset, Summer mode shows no leaf layer by design.
struct SummerLeavesOverlaySeam: View {
    let reduceMotion: Bool

    var body: some View {
        Group {
            if reduceMotion {
                Color.clear
            } else {
                SummerLeavesVideoOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Video

/// Host view that forwards final Auto Layout bounds into `AVPlayerLayer` (SwiftUI often calls `makeUIView` at 0×0).
private final class LeavesVideoHostView: UIView {
    var onBoundsChange: ((CGRect) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onBoundsChange?(bounds)
    }
}

/// Leaf overlay from the bundled loop only. Without `SummerLeavesLoop.mp4`, the overlay is empty (intentional).
struct SummerLeavesVideoOverlay: View {
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "SummerLeavesLoop", withExtension: "mp4") {
                ZStack {
                    LoopingVideoPlayerView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Warm side light: stays subtle so multiply still reads as shadow, not a flat tint.
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.92, blue: 0.82).opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .compositingGroup()
                .blendMode(.multiply)
                .opacity(0.82)
            } else {
                Color.clear
            }
        }
    }
}

private struct LoopingVideoPlayerView: UIViewRepresentable {
    let url: URL
    @Environment(\.scenePhase) private var scenePhase

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIView(context: Context) -> LeavesVideoHostView {
        let view = LeavesVideoHostView()
        view.backgroundColor = .clear
        let coordinator = context.coordinator
        view.onBoundsChange = { [weak coordinator] bounds in
            coordinator?.updateBounds(bounds)
        }
        coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: LeavesVideoHostView, context: Context) {
        context.coordinator.updateBounds(uiView.bounds)
        if scenePhase == .active {
            context.coordinator.resumePlaybackIfAttached()
        }
    }

    static func dismantleUIView(_ uiView: LeavesVideoHostView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        private let url: URL
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var playerLayer: AVPlayerLayer?

        init(url: URL) {
            self.url = url
        }

        func attach(to view: UIView) {
            guard playerLayer == nil else {
                updateBounds(view.bounds)
                return
            }
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.preventsDisplaySleepDuringVideoPlayback = false
            let loop = AVPlayerLooper(player: queue, templateItem: item)
            looper = loop
            player = queue
            let layer = AVPlayerLayer(player: queue)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            playerLayer = layer
            queue.play()
        }

        func updateBounds(_ bounds: CGRect) {
            playerLayer?.frame = bounds
        }

        func resumePlaybackIfAttached() {
            player?.play()
        }

        func teardown() {
            player?.pause()
            looper = nil
            player = nil
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
        }
    }
}
