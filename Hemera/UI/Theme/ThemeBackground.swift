import Mortar
import SwiftUI

/// A Gradient theme's mesh over the colour scheme's base.
struct ThemeBackground: View {
    let gradient: Theme.Gradient

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let paint = gradient.painted(in: colorScheme)
        ZStack {
            Color(white: ThemeMaths.base(in: colorScheme))
            MeshGradient(
                width: 3,
                height: 3,
                points: ThemeMaths.meshPoints,
                colors: ThemeMaths.meshColors(paint.color.swiftUIColor)
            )
            .opacity(paint.alpha)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// The theme behind a navigation screen, and frosted cards on it.
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
}

/// Reads the theme here rather than in the screen, so a colour change doesn't rebuild the screen.
private struct ThemedBackground: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    // One branch for every theme: switching kinds must not rebuild the screen and lose its scroll.
    func body(content: Content) -> some View {
        content
            .containerBackground(for: .navigation) {
                if case .gradient(let gradient) = themeManager.theme {
                    ThemeBackground(gradient: gradient)
                } else {
                    PlatformColor.systemBackground.ignoresSafeArea()
                }
            }
            .environment(\.cardSurface, themeManager.theme == .none ? .wash : .frosted)
    }
}
