import SwiftUI

struct HomeEmptyView: View {
    var body: some View {
        ContentUnavailableView(
            Localization.title,
            systemImage: "house",
            description: Text(Localization.description)
        )
    }
}

private extension HomeEmptyView {
    enum Localization {
        static let title = String(localized: "No Entities Pinned", comment: "Empty state title when no entities are added to the Home screen")
        static let description = String(localized: "Long-press an entity in the Areas tab to add it here.", comment: "Empty state instructions on the Home screen")
    }
}
