import Mortar
import SwiftUI

/// A list row's content: a fixed icon column, a semibold title and an optional grey subtitle.
struct ListRowLabel<IconBadge: View>: View {
    let title: String
    let subtitle: String?
    /// SF Symbol name, or an `mdi:` name.
    let icon: String
    @ViewBuilder let iconBadge: () -> IconBadge

    @ScaledMetric(relativeTo: .title3) private var iconSize = Mortar.IconSize.xs

    var body: some View {
        HStack(spacing: Mortar.Spacing.m) {
            IconImage(icon, size: iconSize)
                .font(.title3)
                .overlay(alignment: .topTrailing, content: iconBadge)
                // A fixed column, so every title starts at the same x whatever the glyph's width.
                .frame(width: Mortar.IconSize.s, height: Mortar.TapTarget.minimum)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.body.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Mortar.Spacing.s)
    }
}

extension ListRowLabel where IconBadge == EmptyView {
    init(title: String, subtitle: String?, icon: String) {
        self.init(title: title, subtitle: subtitle, icon: icon) { EmptyView() }
    }
}
