import SwiftUI

public struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    let seed: Int

    @State private var animating = false
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var angle: Double {
        let base = 1.5 + Double(seed % 3) * 0.5 // 1.5-2.5 range
        return animating ? base : -base
    }

    /// Staggered delay so tiles don't all start wiggling at once.
    private var staggerDelay: Double {
        let hash = abs(seed)
        return Double(hash % 250) / 1000.0
    }

    private var wiggleDuration: Double {
        0.12 + Double(seed % 3) * 0.02
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content
                .overlay {
                    if isWiggling {
                        RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: Mortar.strokeWidth, dash: [6, 4]))
                            .foregroundStyle(.secondary)
                    }
                }
        } else {
            content
                .rotationEffect(.degrees(isWiggling && started ? angle : 0))
                .onChange(of: isWiggling) { _, newValue in
                    if newValue {
                        startWiggleWithDelay()
                    } else {
                        stopWiggle()
                    }
                }
                .onAppear {
                    if isWiggling {
                        startWiggleWithDelay()
                    }
                }
        }
    }

    private func startWiggleWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelay) {
            guard isWiggling else { return }
            started = true
            withAnimation(
                .easeInOut(duration: wiggleDuration)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }

    private func stopWiggle() {
        withAnimation(.easeOut(duration: Mortar.Motion.fast)) {
            animating = false
            started = false
        }
    }
}

extension View {
    public func wiggle(isWiggling: Bool, seed: Int = 0) -> some View {
        modifier(WiggleModifier(isWiggling: isWiggling, seed: seed))
    }
}
