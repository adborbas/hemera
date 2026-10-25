import SwiftUI
import Mortar

/**
 Toggle control shown in Show/Hide mode, positioned and styled like the Home
 layout resize button. Its icon shows the action it performs — an eye-slash on a
 shown entity (tap to hide), an open eye on a hidden one (tap to show). The
 current state is conveyed by the tile dimming, not the icon.
*/
struct HideToggleButton: View {
    let isHidden: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isHidden ? Localization.show : Localization.hide,
                systemImage: isHidden ? "eye" : "eye.slash"
            )
            .labelStyle(.iconOnly)
            .contentTransition(.symbolEffect(.replace))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: Mortar.IconSize.s, height: Mortar.IconSize.s)
            .background(
                Circle()
                    .fill(.thinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            // Minimum tap target (HIG) around the smaller visible circle.
            .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Localization

private extension HideToggleButton {
    enum Localization {
        static let hide = String(localized: "Hide", comment: "Accessibility label for the button that hides a currently-shown entity in show/hide mode")
        static let show = String(localized: "Show", comment: "Accessibility label for the button that reveals a currently-hidden entity in show/hide mode")
    }
}
