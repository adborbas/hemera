import SwiftUI

/// A display-only fill indicator for entity cards.
///
/// Renders a colored rectangle filling from a specified edge (top or bottom),
/// clipped to the standard card rounded rectangle. Used as a background layer
/// on medium-size entity cards to visualise a value level (e.g. brightness, position).
public struct CardFillOverlay: View {

    public enum Anchor {
        case top
        case bottom
    }

    public let fraction: CGFloat
    public let fillColor: Color
    public let fillOpacity: Double
    public let anchor: Anchor

    public init(
        fraction: CGFloat,
        fillColor: Color,
        fillOpacity: Double = 0.25,
        anchor: Anchor
    ) {
        self.fraction = fraction
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
        self.anchor = anchor
    }

    public var body: some View {
        GeometryReader { geo in
            let clamped = min(max(fraction, 0), 1)

            VStack(spacing: 0) {
                if anchor == .bottom {
                    Spacer(minLength: 0)
                }

                Rectangle()
                    .fill(fillColor.opacity(fillOpacity))
                    .frame(height: geo.size.height * clamped)

                if anchor == .top {
                    Spacer(minLength: 0)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous))
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: Mortar.Spacing.m) {
        ZStack {
            RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                .fill(Color.yellow.opacity(0.1))
            CardFillOverlay(fraction: 0.6, fillColor: .yellow, anchor: .bottom)
            Text("Light 60%")
        }
        .frame(width: 180, height: 180)

        ZStack {
            RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                .fill(Color.blue.opacity(0.1))
            CardFillOverlay(fraction: 0.75, fillColor: .blue, anchor: .top)
            Text("Cover 75%")
        }
        .frame(width: 180, height: 180)
    }
    .padding()
}
#endif
