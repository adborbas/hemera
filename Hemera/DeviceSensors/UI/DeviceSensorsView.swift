import Mortar
import SwiftUI

/// A device's sensors and binary sensors, pushed from its control panel.
struct DeviceSensorsView: View {
    let viewModel: DeviceSensorsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Mortar.Spacing.s) {
                ForEach(viewModel.rows) { DeviceSensorRow(row: $0) }
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

// MARK: - Row

/// A constant-height card: the name across the top, the value below.
private struct DeviceSensorRow: View {
    let row: DeviceSensorsViewModel.Row

    @ScaledMetric(relativeTo: .body) private var height = 72

    var body: some View {
        HStack(spacing: Mortar.Spacing.m) {
            MDIIcon(name: row.icon ?? Constants.fallbackIcon, size: Mortar.IconSize.xs)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Mortar.Spacing.xxs) {
                Text(row.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(row.value)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Mortar.Spacing.m)
        .frame(height: height)
        .cardBackground()
        .accessibilityElement(children: .combine)
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
