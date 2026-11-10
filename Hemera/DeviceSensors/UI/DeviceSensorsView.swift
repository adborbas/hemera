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

/// A constant-height card; name and value wrap to two lines and truncate after that.
private struct DeviceSensorRow: View {
    let row: DeviceSensorsViewModel.Row

    @ScaledMetric(relativeTo: .subheadline) private var height = 72
    @ScaledMetric(relativeTo: .headline) private var valueMaxWidth = 140

    var body: some View {
        HStack(spacing: Mortar.Spacing.m) {
            MDIIcon(name: row.icon ?? Constants.fallbackIcon, size: Mortar.IconSize.xs)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
                NameValueLayout(valueMaxWidth: valueMaxWidth, spacing: Mortar.Spacing.s) {
                    Text(row.name)
                        .font(.subheadline.weight(.medium))
                    Text(row.value)
                        .font(.system(.headline, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                .lineLimit(2)
                if row.percent != nil || row.timeLeft != nil {
                    HStack(spacing: Mortar.Spacing.s) {
                        if let percent = row.percent { LevelBar(percent: percent) }
                        if let timeLeft = row.timeLeft {
                            Text(Localization.timeLeft(timeLeft))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Mortar.Spacing.m)
        .frame(height: height)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}

/// Name leading, value trailing, both centred; the value takes its own width up to `valueMaxWidth`.
private struct NameValueLayout: Layout {
    let valueMaxWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (name, value) = sizes(width: proposal.width ?? .infinity, subviews: subviews)
        let width = proposal.width ?? name.width + spacing + value.width
        return CGSize(width: width, height: max(name.height, value.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (name, value) = sizes(width: bounds.width, subviews: subviews)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .init(name))
        subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .init(value))
    }

    private func sizes(width: CGFloat, subviews: Subviews) -> (name: CGSize, value: CGSize) {
        let valueWidth = min(subviews[1].sizeThatFits(.unspecified).width, valueMaxWidth, width)
        let value = subviews[1].sizeThatFits(.init(width: valueWidth, height: nil))
        let name = subviews[0].sizeThatFits(.init(width: max(0, width - valueWidth - spacing), height: nil))
        return (name, value)
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
