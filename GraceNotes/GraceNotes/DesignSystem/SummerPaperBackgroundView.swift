import SwiftUI

/// Full-screen warm paper field (gradient + light grain). Sits behind Today journal content in Bloom mode.
struct SummerPaperBackgroundView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 0.90),
                        Color(red: 0.94, green: 0.89, blue: 0.82),
                        Color(red: 0.91, green: 0.86, blue: 0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if !reduceTransparency {
                    PaperFibersCanvas(size: proxy.size)
                        .opacity(0.14)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct PaperFibersCanvas: View {
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let grainCount = 90
            var rng = SeededRandom(seed: 42)
            for _ in 0..<grainCount {
                let x = CGFloat(rng.next()) * canvasSize.width
                let y = CGFloat(rng.next()) * canvasSize.height
                let length = 6 + CGFloat(rng.next()) * 22
                let angle = CGFloat(rng.next()) * .pi
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(
                    to: CGPoint(
                        x: x + cos(angle) * length,
                        y: y + sin(angle) * length
                    )
                )
                context.stroke(
                    path,
                    with: .color(Color(red: 0.42, green: 0.36, blue: 0.30).opacity(0.12)),
                    lineWidth: 0.35
                )
            }
        }
        .drawingGroup(opaque: false)
    }
}

private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1
        return Double(state & 0xFFFF_FFFF) / Double(0xFFFF_FFFF)
    }
}
