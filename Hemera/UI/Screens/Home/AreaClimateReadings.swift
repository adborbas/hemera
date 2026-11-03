import SwiftUI
import Mortar

/// An area's temperature and humidity as pills, each a tappable link to its own history.
struct AreaClimateReadings: View {
    @Bindable var area: AreaEntity
    /// 0 draws pills, 1 a compact line; a collapsing header drives the values in between.
    var morph: CGFloat = 0
    /// Off once collapsed into a subtitle: the readings stay on show but no longer open their history.
    var isInteractive = true

    @ScaledMetric(relativeTo: .subheadline) private var iconSize = Mortar.IconSize.xs
    @Environment(\.colorScheme) private var colorScheme

    /// Held in state so a re-render cannot swap in a fresh, unloaded view model.
    @State private var climateHistoryTarget: ClimateHistoryTarget?

    var body: some View {
        let (temperatureText, humidityText) = AreaDisplayHelpers.climateSummary(for: area)
        let representatives = AreaDisplayHelpers.representativeSensors(for: area)

        if temperatureText != nil || humidityText != nil {
            HStack(spacing: Mortar.Spacing.s + (Mortar.Spacing.m - Mortar.Spacing.s) * morph) {
                if let temperatureText, let temperature = representatives.temperature {
                    climateHistoryButton(
                        text: temperatureText,
                        sensor: temperature,
                        fallbackUnit: "°",
                        icon: "mdi:thermometer"
                    )
                }

                if let humidityText, let humidity = representatives.humidity {
                    climateHistoryButton(
                        text: humidityText,
                        sensor: humidity,
                        fallbackUnit: "%",
                        icon: "mdi:water-percent"
                    )
                }
            }
            .sheet(item: $climateHistoryTarget) { target in
                AreaClimateHistoryView(
                    viewModel: target.viewModel,
                    areaName: area.name
                )
                .presentationDetents([.large])
            }
        }
    }

    /// A reading that opens its own sensor's history sheet while interactive.
    @ViewBuilder
    private func climateHistoryButton(
        text: String,
        sensor: SensorEntity,
        fallbackUnit: String,
        icon: String
    ) -> some View {
        if isInteractive {
            Button {
                guard let session = ServiceLocator.shared.session else { return }
                climateHistoryTarget = ClimateHistoryTarget(
                    viewModel: AreaClimateHistoryViewModel(
                        sensor: sensor,
                        fallbackUnit: fallbackUnit,
                        provider: session.sensorHistoryProvider
                    )
                )
            } label: {
                readingLabel(text: text, icon: icon)
            }
            .buttonStyle(.plain)
        } else {
            readingLabel(text: text, icon: icon)
                .accessibilityElement(children: .combine)
        }
    }

    private func readingLabel(text: String, icon: String) -> some View {
        HStack(spacing: Mortar.Spacing.xs) {
            // Tinted so the glyph reads as its own thing rather than competing with the value.
            MDIIcon(name: icon, size: iconSize)
                .foregroundStyle(Color.cool)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Mortar.Spacing.l * (1 - morph))
        .frame(minHeight: Mortar.TapTarget.minimum * (1 - morph))
        .background {
            Capsule().fill(PillFill.unselected(colorScheme)).opacity(1 - morph)
        }
        .contentShape(Rectangle())
    }

    /// Identified by its view model, so a tap is one target for `.sheet(item:)`.
    private struct ClimateHistoryTarget: Identifiable {
        let viewModel: AreaClimateHistoryViewModel
        var id: ObjectIdentifier { ObjectIdentifier(viewModel) }
    }
}
