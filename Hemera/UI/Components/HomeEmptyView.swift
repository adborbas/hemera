import SwiftUI

struct HomeEmptyView: View {
    @Environment(\.openFeed) private var openFeed

    var body: some View {
        ContentUnavailableView {
            Label(Localization.title, systemImage: "house")
        } description: {
            Text(Localization.description)
        } actions: {
            if let openFeed {
                Button(Localization.showAreas) { openFeed(.areas) }
            }
        }
    }
}

private extension HomeEmptyView {
    enum Localization {
        static let title = String(localized: "No Entities Pinned", comment: "Empty state title when no entities are added to the Home screen")
        static let description = String(localized: "Long-press an entity in Areas to add it here.", comment: "Empty state instructions on the Home screen")
        static let showAreas = String(localized: "Show Areas", comment: "Button in the Home empty state that switches to the Areas feed")
    }
}
