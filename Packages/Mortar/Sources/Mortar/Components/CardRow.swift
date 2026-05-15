import SwiftUI

public struct CardRow<Trailing: View>: View {

    public let iconName: String
    public let iconColor: Color
    public let title: String
    public let subtitle: String
    public let action: () -> Void
    public let trailing: Trailing

    public init(
        iconName: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.trailing = trailing()
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Mortar.Spacing.m) {
                CardIcon(iconName: iconName, backgroundColor: iconColor)

                VStack(alignment: .leading, spacing: Mortar.Spacing.xxs) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                trailing
            }
            .padding(.vertical, Mortar.Spacing.l)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardBackground()
    }
}

#if DEBUG
#Preview {
    VStack(spacing: Mortar.Spacing.s) {
        CardRow(
            iconName: "server.rack",
            iconColor: .green,
            title: "Home",
            subtitle: "192.168.68.54",
            action: {}
        ) {
            DisclosureIndicator()
        }

        CardRow(
            iconName: "keyboard",
            iconColor: .blue,
            title: "Enter address manually",
            subtitle: "Type your server URL",
            action: {}
        ) {
            DisclosureIndicator()
        }
    }
    .padding(Mortar.Spacing.xl)
}
#endif
