import SwiftUI

public struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    let seed: Int

    @State private var animating = false
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Peak rotation, identical for every tile so they all sweep the same
    /// distance.
    private static let angleBase = 2.0

    /// Duration of a single sweep, identical for every tile so they all wiggle
    /// at the same frequency.
    private static let wiggleDuration = 0.14

    /// Current rotation. Zero until the start fires, then oscillates between
    /// -angleBase and +angleBase as `animating` toggles.
    ///
    /// Gated on `started` (not `isWiggling`) so that on exit the return to zero
    /// lands in the same transaction as `animating` flipping false — the
    /// ease-out then replaces the running `repeatForever`. Gating on the
    /// external `isWiggling` would zero the rotation a render too early, leaving
    /// the repeat with no delta to cancel against.
    private var rotation: Double {
        guard started else { return 0 }
        return animating ? Self.angleBase : -Self.angleBase
    }

    /// Repeating wiggle while running; a gentle ease-out once `started` clears
    /// so the tile settles back to upright instead of snapping.
    ///
    /// Tiles share frequency and amplitude but start at a per-seed point in the
    /// cycle (`phaseOffset`), so they move in lockstep yet out of phase rather
    /// than all tilting the same way at the same instant.
    private var rotationAnimation: Animation {
        started
            ? .easeInOut(duration: Self.wiggleDuration)
                .repeatForever(autoreverses: true)
                .delay(phaseOffset)
            : .easeOut(duration: Mortar.Motion.fast)
    }

    /// Per-seed offset spread across one full oscillation cycle (a sweep there
    /// and back), giving each tile a distinct, stable phase.
    private var phaseOffset: Double {
        let cycle = Self.wiggleDuration * 2
        return Double(seed.magnitude % 100) / 100.0 * cycle
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
