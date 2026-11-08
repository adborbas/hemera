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
        EditBadgeButton(
            isHidden ? Localization.show : Localization.hide,
            systemImage: isHidden ? "eye" : "eye.slash",
            action: action
        )
        .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Localization

private extension HideToggleButton {
    enum Localization {
        static let hide = String(localized: "Hide", comment: "Accessibility label for the button that hides a currently-shown entity in show/hide mode")
        static let show = String(localized: "Show", comment: "Accessibility label for the button that reveals a currently-hidden entity in show/hide mode")
    }
}
