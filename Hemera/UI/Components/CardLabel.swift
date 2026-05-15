import SwiftUI
import Mortar

struct CardLabel<Subtitle: View>: View {
    let title: String
    var accessibilityIdentifier: String?
    let subtitle: Subtitle
    @Environment(\.isMediumTile) private var isMediumTile

    init(title: String, accessibilityIdentifier: String? = nil, @ViewBuilder subtitle: () -> Subtitle) {
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.subtitle = subtitle()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
            if let id = accessibilityIdentifier {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(isMediumTile ? 2 : 1)
                    .accessibilityIdentifier(id)
            } else {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(isMediumTile ? 2 : 1)
            }
            subtitle
        }
    }
}

extension CardLabel where Subtitle == CardLabelTextSubtitle {
    init(title: String, subtitle: String, accessibilityIdentifier: String? = nil) {
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.subtitle = CardLabelTextSubtitle(text: subtitle)
    }
}

struct CardLabelTextSubtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
