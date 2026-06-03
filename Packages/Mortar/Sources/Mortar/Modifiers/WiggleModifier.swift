import SwiftUI

public struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    let seed: Int

    @State private var animating = false
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Peak rotation for this tile, varied per seed (1.5°-2.5°).
    private var angleBase: Double {
        1.5 + Double(seed % 3) * 0.5
    }

    /// Current rotation. Zero until the staggered start fires, then oscillates
    /// between -angleBase and +angleBase as `animating` toggles.
    private var rotation: Double {
        guard isWiggling, started else { return 0 }
        return animating ? angleBase : -angleBase
    }

    /// Repeating wiggle while running; a gentle ease-out once `started` clears
    /// so the tile settles back to upright instead of snapping.
    private var rotationAnimation: Animation {
        started
            ? .easeInOut(duration: wiggleDuration).repeatForever(autoreverses: true)
            : .easeOut(duration: Mortar.Motion.fast)
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
                .rotationEffect(.degrees(rotation))
                // Declarative animation: registers `repeatForever` in the view
                // graph so it keeps oscillating. (Imperative `withAnimation`
                // from an async `.task` continuation only applies the final
                // value statically and never runs the repeat.)
                .animation(rotationAnimation, value: animating)
                .task(id: isWiggling) {
                    if isWiggling {
                        try? await Task.sleep(for: .seconds(staggerDelay))
                        guard !Task.isCancelled else { return }
                        // Snap to the -angleBase resting tilt (unanimated: only
                        // `animating` is tracked), let SwiftUI render it, then
                        // toggle `animating` so the repeat sweeps symmetrically
                        // from -angleBase to +angleBase.
                        started = true
                        try? await Task.sleep(for: .milliseconds(1))
                        guard !Task.isCancelled else { return }
                        animating = true
                    } else {
                        started = false
                        animating = false
                    }
                }
        }
    }
}

extension View {
    public func wiggle(isWiggling: Bool, seed: Int = 0) -> some View {
        modifier(WiggleModifier(isWiggling: isWiggling, seed: seed))
    }
}
