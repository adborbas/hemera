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
        .navigationDestination(for: DeviceSensorsViewModel.Row.self) { DeviceSensorDetailView(row: $0) }
    }
}

// MARK: - Row

/// A constant-height card; one whose name or value is cut short drills down to the full text.
private struct DeviceSensorRow: View {
    let row: DeviceSensorsViewModel.Row

    @ScaledMetric(relativeTo: .subheadline) private var height = 56
    @ScaledMetric(relativeTo: .headline) private var valueMaxWidth = 140
    @State private var isNameTruncated = false
    @State private var isValueTruncated = false

    var body: some View {
        if isNameTruncated || isValueTruncated {
            NavigationLink(value: row) { card(showsDisclosure: true) }
                .buttonStyle(.plain)
        } else {
            card(showsDisclosure: false)
        }
    }

    private func card(showsDisclosure: Bool) -> some View {
        HStack(spacing: Mortar.Spacing.m) {
            MDIIcon(name: row.icon ?? Constants.fallbackIcon, size: Mortar.IconSize.xs)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    TruncatingText(row.name, font: .subheadline.weight(.medium), isTruncated: $isNameTruncated)
                    Spacer(minLength: Mortar.Spacing.s)
                    TruncatingText(
                        row.value, font: .system(.headline, design: .rounded),
                        maxWidth: valueMaxWidth, isTruncated: $isValueTruncated
                    )
                    .monospacedDigit()
                    .layoutPriority(1)
                }
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
            if showsDisclosure { DisclosureIndicator() }
        }
        .padding(.horizontal, Mortar.Spacing.m)
        .frame(height: height)
        .cardBackground()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Detail

/// Everything a row had to cut short, wrapped instead of truncated.
private struct DeviceSensorDetailView: View {
    let row: DeviceSensorsViewModel.Row

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Mortar.Spacing.m) {
                Text(row.name)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: Mortar.Spacing.s) {
                    Text(row.value)
                        .font(.system(.headline, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    if let percent = row.percent { LevelBar(percent: percent) }
                    if let timeLeft = row.timeLeft {
                        Text(Localization.timeLeft(timeLeft)).foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Mortar.Spacing.m)
                .cardBackground()
            }
            .padding(.horizontal, Mortar.Spacing.l)
        }
        .reportsFeedScroll()
        .pushedScreenHeader(row.name, staysCollapsed: true)
        .background(.ultraThickMaterial)
        .containerBackground(.clear, for: .navigation)
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

/// One line of text that reports whether it got cut short; no wider than `maxWidth` when given.
private struct TruncatingText: View {
    let text: String
    let font: Font
    let maxWidth: CGFloat?
    @Binding var isTruncated: Bool

    @State private var shownWidth: CGFloat = 0
    @State private var fullWidth: CGFloat = 0

    init(_ text: String, font: Font, maxWidth: CGFloat? = nil, isTruncated: Binding<Bool>) {
        self.text = text
        self.font = font
        self.maxWidth = maxWidth
        _isTruncated = isTruncated
    }

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { shownWidth = $0; update() }
            .frame(width: maxWidth.map { min(fullWidth.rounded(.up), $0) }, alignment: .trailing)
            .background {
                Text(text)
                    .font(font)
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fullWidth = $0; update() }
            }
    }

    private func update() {
        isTruncated = fullWidth > shownWidth + 0.5
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
