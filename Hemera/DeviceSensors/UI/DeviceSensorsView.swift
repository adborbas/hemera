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
        .background(.ultraThickMaterial)
        .containerBackground(.clear, for: .navigation)
    }
}

// MARK: - Row

/// A constant-height card: the name across the top, the value with its level and time left below.
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
                HStack(spacing: Mortar.Spacing.m) {
                    Text(row.value)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                    if let percent = row.percent { LevelBar(percent: percent) }
                    if let timeLeft = row.timeLeft {
                        Text(Localization.timeLeft(timeLeft))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Mortar.Spacing.m)
        .frame(height: height)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pieces

private struct LevelBar: View {
    let percent: Double

    var body: some View {
        Capsule()
            .fill(.fill.tertiary)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.secondary)
                        .frame(width: proxy.size.width * min(max(percent, 0), 100) / 100)
                }
            }
            .frame(height: Constants.barHeight)
            .accessibilityHidden(true)
    }
}

// MARK: - Constants

private enum Constants {
    static let fallbackIcon = "mdi:eye"
    static let barHeight: CGFloat = 6
}

// MARK: - Localization

private enum Localization {
    static let sensors = String(
        localized: "Sensors",
        comment: "Title of the page listing a device's sensors, pushed from its control panel"
    )

    static func timeLeft(_ time: String) -> String {
        String(
            localized: "\(time) left",
            comment: "Time remaining for a part, e.g. '58 h left', under its life bar on a device's Sensors page"
        )
    }
}
