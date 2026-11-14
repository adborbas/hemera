import Mortar
import SwiftUI

/// The Theme step: the theme editor over the Home step's grid, which stays where it is.
struct OnboardingThemeStep: ViewModifier {

    let isShown: Bool
    /// Changes on Reset, so the editor starts over on None.
    let resetCount: Int

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isCompact = horizontalSizeClass == .compact
        content
            // The same placement and transition as the main app's editor, above the bottom button.
            .overlay(alignment: isCompact ? .bottom : .bottomTrailing) {
                if isShown {
                    Editor(isDrawer: isCompact)
                        .frame(width: isCompact ? nil : 360)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(isCompact ? 0 : Mortar.Spacing.xl)
                        .id(resetCount)
                        .transition(transition(isCompact: isCompact))
                }
            }
    }

    private func transition(isCompact: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return isCompact ? .move(edge: .bottom) : .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
    }
}

/// Reads the theme here, so a colour change doesn't rebuild the grid.
private struct Editor: View {
    let isDrawer: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ThemeEditorView(theme: themeManager.theme, isDrawer: isDrawer, showsActions: false)
    }
}
