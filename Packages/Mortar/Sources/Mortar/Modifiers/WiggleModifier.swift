import SwiftUI

public struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    let seed: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Peak rotation, identical for every tile so they all sweep the same
    /// distance.
    private static let angleBase = 2.0

    /// One full oscillation (a sweep there and back), identical for every
    /// tile so they all wiggle at the same frequency.
    private static let cycleDuration = 0.28

    /// Per-seed offset into the oscillation cycle, giving each tile a
    /// distinct, stable phase.
    private var phase: Double {
        Double(seed.magnitude % 100) / 100.0 * 2 * .pi
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
            // Rotation is a pure function of wall-clock time, so the wiggle
            // needs no stored animation state: it survives view identity
            // changes and can never end up statically stuck mid-tilt (the
            // failure mode of toggling a `repeatForever` from a task).
            // Start/stop transitions inherit the caller's `withAnimation`.
            TimelineView(.animation(minimumInterval: nil, paused: !isWiggling)) { context in
                content
                    .rotationEffect(.degrees(angle(at: context.date)))
            }
        }
    }

    private func angle(at date: Date) -> Double {
        guard isWiggling else { return 0 }
        let t = date.timeIntervalSinceReferenceDate
        return sin((t / Self.cycleDuration) * 2 * .pi + phase) * Self.angleBase
    }
}

extension View {
    public func wiggle(isWiggling: Bool, seed: Int = 0) -> some View {
        modifier(WiggleModifier(isWiggling: isWiggling, seed: seed))
    }
}
