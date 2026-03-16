import SwiftUI

struct WiggleModifier: ViewModifier {
    let isActive: Bool

    @State private var phase: CGFloat = 0
    @State private var phaseOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? 2 * sin(Double(phase * .pi * 2 + phaseOffset)) : 0))
            .offset(y: isActive ? 2 * sin(Double(phase * .pi * 2 + phaseOffset + 0.1)) : 0)
            .animation(
                isActive
                    ? .easeInOut(duration: 0.12)
                    .repeatForever(autoreverses: true)
                    : .default,
                value: phase
            )
            .onAppear {
                phaseOffset = CGFloat.random(in: 0..<(2 * .pi))
                if isActive { phase = 1 }
            }
            .onChange(of: isActive) { _, active in
                phase = active ? 1 : 0
            }
    }
}

extension View {
    func wiggle(isActive: Bool) -> some View {
        modifier(WiggleModifier(isActive: isActive))
    }
}
