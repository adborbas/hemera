import SwiftUI

// MARK: - Icon Anchor

/**
 Published by `CardIcon` so a card's background knows where its icon sits, without having to
 re-derive the content layout (which differs between small and medium tiles).
*/
struct CardIconCenterKey: PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil

    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
    }
}

/// Where the glow disc's flat core ends and its soft rim begins.
private let solidFraction: CGFloat = 0.82

// MARK: - Glow Background

/**
 An active card's tint wash, revealed by a disc growing out of the icon — light spilling from the
 lamp — and drawn back into it on deactivation.

 The wash is semi-transparent over the app background, so layering it on top of the inactive grey
 would tint it a different colour than a plain `cardBackground` produces. Instead the opaque grey
 sits *above* the wash and the disc punches a hole through it, which keeps both resting states
 pixel-identical to the static background.
*/
struct CardGlowBackground<LitOverlay: View>: View {

    // MARK: - Properties

    let tint: Color
    let isActive: Bool
    let iconCenter: CGPoint
    /// Drawn with the wash, so the glow reveals and retracts the two as one lit surface.
    @ViewBuilder let litOverlay: () -> LitOverlay

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let radius = discRadius(in: geometry.size)

            ZStack {
                shape.fill(Mortar.cardTintWash(tint, in: colorScheme))
                litOverlay()

                ZStack {
                    shape.fill(PlatformColor.secondarySystemBackground)
                    disc(radius: radius).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
        }
    }

    // MARK: - Private

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
    }

    /// White carries no colour here — it is a knockout mask, so only the alpha ramp is visible.
    private func disc(radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: .white, location: solidFraction),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(isActive ? 1 : 0.001)
            .position(iconCenter)
            .animation(isActive ? Mortar.Motion.glowExpand : Mortar.Motion.glowCollapse, value: isActive)
    }

    /**
     Sized so the flat core alone reaches the farthest corner at full scale: the soft rim then falls
     outside the card, leaving the expanded wash as even as the static one.
    */
    private func discRadius(in size: CGSize) -> CGFloat {
        let dx = max(iconCenter.x, size.width - iconCenter.x)
        let dy = max(iconCenter.y, size.height - iconCenter.y)
        return (dx * dx + dy * dy).squareRoot() / solidFraction
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var isActive = false

    VStack(spacing: Mortar.Spacing.l) {
        ForEach([CGSize(width: 170, height: 170), CGSize(width: 170, height: 80)], id: \.height) { size in
            CardGlowBackground(tint: .yellow,
                               isActive: isActive,
                               iconCenter: CGPoint(x: 36, y: size.height == 80 ? 40 : 36)) {
                EmptyView()
            }
            .frame(width: size.width, height: size.height)
        }

        Button("Toggle") { isActive.toggle() }
    }
    .padding()
}
#endif
