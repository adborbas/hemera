import SwiftUI

private struct CardBackgroundModifier: ViewModifier {
    let tint: Color?
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: Mortar.Radii.l, style: .continuous)
                .fill(fillColor)
        )
    }

    private var fillColor: Color {
        guard let tint else {
            return PlatformColor.secondarySystemBackground
        }
        let tintOpacity = colorScheme == .dark ? 0.28 : 0.15
        return isActive ? tint.opacity(tintOpacity) : PlatformColor.secondarySystemBackground
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
    public func cardBackground(tint: Color? = nil, isActive: Bool = false) -> some View {
        modifier(CardBackgroundModifier(tint: tint, isActive: isActive))
    }
}
