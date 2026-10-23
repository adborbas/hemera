import SwiftUI

// MARK: - Icon Anchor

/// Published by `CardIcon` so the background need not re-derive where the icon sits.
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
 An active card's tint wash, revealed by a disc growing out of the icon and drawn back in on
 deactivation. The wash is semi-transparent, so the opaque grey sits *above* it and the disc
 punches a hole through — layering the wash on the grey would tint it a different colour.
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

    /// Oversized so the flat core reaches the farthest corner and the soft rim falls outside.
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
