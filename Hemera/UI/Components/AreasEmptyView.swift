import SwiftUI

struct AreasEmptyView: View {
    var body: some View {
        ContentUnavailableView(
            Localization.title,
            systemImage: "square.grid.2x2",
            description: Text(Localization.description)
        )
    }
}

private extension AreasEmptyView {
    enum Localization {
        static let title = String(localized: "No Areas Found", comment: "Empty state title when no areas with entities exist")
        static let description = String(localized: "Areas from your Home Assistant will appear here once they have entities.", comment: "Empty state description on the Areas screen when no areas contain entities")
    }
}
