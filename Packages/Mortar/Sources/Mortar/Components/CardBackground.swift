import SwiftUI

private struct CardBackgroundModifier<LitOverlay: View>: ViewModifier {
    let tint: Color?
    let isActive: Bool
    let glowsFromIcon: Bool
    @ViewBuilder let litOverlay: () -> LitOverlay
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.backgroundPreferenceValue(CardIconCenterKey.self) { iconAnchor in
            // Reduce Motion takes the plain fill: same two resting states, reached without travel.
            if glowsFromIcon, !reduceMotion, let tint, let iconAnchor {
                // Only to resolve the anchor — the background already spans the card's bounds.
                GeometryReader { geometry in
                    CardGlowBackground(tint: tint,
                                       isActive: isActive,
                                       iconCenter: geometry[iconAnchor],
                                       litOverlay: litOverlay)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                        .fill(fillColor)
                    litOverlay()
                }
            }
        }
    }

    private var fillColor: Color {
        guard let tint else {
            return PlatformColor.secondarySystemBackground
        }
        return isActive ? Mortar.cardTintWash(tint, in: colorScheme) : PlatformColor.secondarySystemBackground
    }
}

extension Mortar {
    /// The wash an active, tinted card shows instead of its grey background.
    static func cardTintWash(_ tint: Color, in colorScheme: ColorScheme) -> Color {
        tint.opacity(colorScheme == .dark ? 0.28 : 0.15)
    }
}

extension View {
    /// Applies the standard card background.
    ///
    /// When `tint` is provided, the background adapts by color scheme:
    /// - **Light mode**: active cards get a tinted wash (15% opacity).
    /// - **Dark mode**: active cards get a stronger tinted wash (28% opacity).
    /// - Inactive cards use `secondarySystemBackground` regardless of mode.
    ///
    /// When `tint` is `nil`, uses `secondarySystemBackground` regardless of mode.
    ///
    /// `glowsFromIcon` reveals the wash with a glow growing out of the content's `CardIcon`,
    /// reaching the same two resting states. `litOverlay` draws on top of the wash — put a value
    /// indicator there, not over the card, so the glow carries it in and out too.
    public func cardBackground<LitOverlay: View>(
        tint: Color? = nil,
        isActive: Bool = false,
        glowsFromIcon: Bool = false,
        @ViewBuilder litOverlay: @escaping () -> LitOverlay = { EmptyView() }
    ) -> some View {
        modifier(CardBackgroundModifier(tint: tint,
                                        isActive: isActive,
                                        glowsFromIcon: glowsFromIcon,
                                        litOverlay: litOverlay))
    }
}
