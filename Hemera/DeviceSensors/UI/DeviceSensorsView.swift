import Mortar
import SwiftUI

/// A device's sensors and binary sensors, pushed from its control panel.
struct DeviceSensorsView: View {
    let viewModel: DeviceSensorsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Mortar.Spacing.xs) {
                ForEach(viewModel.rows) { row in
                    ListRowLabel(
                        title: row.name, subtitle: row.value,
                        icon: row.icon.map { "mdi:\($0)" } ?? Constants.fallbackIcon
                    )
                    .lineLimit(1)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Mortar.Spacing.l)
            .padding(.bottom, Mortar.Spacing.xl)
        }
        .reportsFeedScroll()
        .pushedScreenHeader(Localization.sensors, staysCollapsed: true)
        .background(PlatformColor.systemBackground)
        .containerBackground(.clear, for: .navigation)
    }
}

// MARK: - Constants

private enum Constants {
    static let fallbackIcon = "mdi:eye"
}

// MARK: - Localization

private enum Localization {
    static let sensors = String(
        localized: "Sensors",
        comment: "Title of the page listing a device's sensors, pushed from its control panel"
    )
}
