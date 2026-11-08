import SwiftUI

/// Long-press actions for an entity card shown outside Home.
struct EntityCardContextMenu: View {
    let isOnHome: Bool
    let isDemoMode: Bool
    let addToHome: () -> Void
    let openInHomeAssistant: () -> Void
    var showHideItems: (() -> Void)?

    var body: some View {
        if !isOnHome {
            Button(action: addToHome) {
                Label(Localization.addToHome, systemImage: "plus")
            }
        }
        if !isDemoMode, let showHideItems {
            Button(action: showHideItems) {
                Label(Localization.showHideItems, systemImage: "eye.slash")
            }
        }
        if !isDemoMode {
            Button(action: openInHomeAssistant) {
                Label(Localization.openInHomeAssistant, systemImage: "globe")
            }
        }
    }
}

private extension EntityCardContextMenu {
    enum Localization {
        static let showHideItems = String(localized: "Show/Hide Items", comment: "Context menu action that enters a mode for hiding or revealing entities in an area")
        static let addToHome = String(localized: "Add to Home", comment: "Context menu action to pin an entity to the Home screen")
        static let openInHomeAssistant = String(localized: "Open in Home Assistant", comment: "Context menu action to open an entity or area in the Home Assistant web interface")
    }
}
