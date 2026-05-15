import SwiftUI
import Mortar

struct TileEntranceModifier: ViewModifier {
    let index: Int
    let isActive: Bool

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
            .onAppear {
                guard isActive, !appeared else {
                    appeared = true
                    return
                }
                if reduceMotion {
                    appeared = true
                    return
                }
                // Base delay lets the root exit transition (welcome scaling down) mostly
                // complete before tiles start appearing — creates a clear exit → entrance sequence.
                let baseDelay = 0.15
                // Cap stagger at index 15 so large grids don't drag on.
                let staggerDelay = Double(min(index, 15)) * Mortar.Motion.staggerInterval
                withAnimation(Mortar.Motion.springSnappy.delay(baseDelay + staggerDelay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func tileEntrance(index: Int, isActive: Bool) -> some View {
        modifier(TileEntranceModifier(index: index, isActive: isActive))
    }
}
