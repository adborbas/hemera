import SwiftUI

private struct CardBackgroundModifier<BackgroundOverlay: View>: ViewModifier {
    let tint: Color?
    let isActive: Bool
    let isWorking: Bool
    @ViewBuilder let backgroundOverlay: () -> BackgroundOverlay
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                        .fill(fillColor)
                    backgroundOverlay()
                }
            }
            .overlay {
                ActivityBorder(color: tint ?? PlatformColor.systemGray,
                               isActive: isWorking && !reduceMotion,
                               cornerRadius: Mortar.Radii.l)
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
    /// `isWorking` traces the card's border with a travelling segment while a task is in flight.
    ///
    /// `backgroundOverlay` draws on top of the fill, within the card's rounded shape.
    public func cardBackground<BackgroundOverlay: View>(
        tint: Color? = nil,
        isActive: Bool = false,
        isWorking: Bool = false,
        @ViewBuilder backgroundOverlay: @escaping () -> BackgroundOverlay = { EmptyView() }
    ) -> some View {
        modifier(CardBackgroundModifier(tint: tint,
                                        isActive: isActive,
                                        isWorking: isWorking,
                                        backgroundOverlay: backgroundOverlay))
    }
}
