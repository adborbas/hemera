import Charts
import Mortar
import SwiftUI

/// Stacked temperature and humidity charts for an area's representative sensors.
struct AreaClimateHistoryView: View {

    var viewModel: AreaClimateHistoryViewModel
    let areaName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let now = Date()
        // Both plots share one domain, derived from the selected range so they rescale together.
        let window = now.addingTimeInterval(-viewModel.selectedRange.interval)...now

        NavigationStack {
            VStack(spacing: Mortar.Spacing.l) {
                Picker(Localization.range, selection: rangeSelection) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(rangeLabel(range)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Mortar.Spacing.l)

                ScrollView {
                    VStack(alignment: .leading, spacing: Mortar.Spacing.xl) {
                        plot(state: viewModel.temperature, color: .warm, window: window)
                        plot(state: viewModel.humidity, color: .cool, window: window)
                    }
                    .padding(Mortar.Spacing.l)
                }
            }
            .navigationTitle(areaName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Label(Localization.close, systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .task(id: viewModel.selectedRange) { await viewModel.load() }
        }
    }

    // MARK: - Range picker

    private var rangeSelection: Binding<TimeRange> {
        Binding(
            get: { viewModel.selectedRange },
            set: { viewModel.selectedRange = $0 }
        )
    }

    // MARK: - Plot

    /// One measurement's current outcome. `.unavailable` draws nothing at all.
    @ViewBuilder
    private func plot(
        state: AreaClimateHistoryViewModel.SeriesState,
        color: Color,
        window: ClosedRange<Date>
    ) -> some View {
        switch state {
        case .unavailable:
            EmptyView()

        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(height: Self.plotHeight)
                .frame(maxWidth: .infinity)

        case .noRecordedHistory:
            Text(Localization.noRecordedHistory)
                .foregroundStyle(.secondary)

        case .failed:
            Text(Localization.loadFailed)
                .foregroundStyle(.secondary)

        case let .loaded(series):
            VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
                Text("\(series.sensorName) (\(series.unit))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // One line per run, so a gap reads as a break rather than a straight line.
                Chart {
                    ForEach(Array(ClimateSampleRuns.split(series.samples).enumerated()), id: \.offset) { run in
                        ForEach(run.element, id: \.start) { sample in
                            LineMark(
                                x: .value(Localization.timeAxis, sample.start),
                                y: .value(Localization.meanAxis, sample.mean),
                                series: .value(Localization.runKey, run.offset)
                            )
                            .foregroundStyle(color)
                        }
                    }
                }
                .chartXScale(domain: window)
                .chartLegend(.hidden)
                .frame(height: Self.plotHeight)
            }
        }
    }
}

// MARK: - Localization

private extension AreaClimateHistoryView {
    enum Localization {
        static let close = String(localized: "Close", comment: "Toolbar button that dismisses the area's climate-history sheet")
        static let noRecordedHistory = String(localized: "No recorded history", comment: "Shown under a climate chart when the sensor has no stored long-term statistics")
        static let loadFailed = String(localized: "Couldn't load history", comment: "Shown under a climate chart when the history fetch failed and may be retried later")
        static let timeAxis = String(localized: "Time", comment: "Horizontal axis key for a climate-history chart, over the selected range")
        static let meanAxis = String(localized: "Mean", comment: "Vertical axis key for a climate-history chart, holding each bucket's mean")
        /// Not user-facing: the legend is hidden, this only keeps each run a separate series.
        static let runKey = "Run"
        static let range = String(localized: "Time range", comment: "Title of the picker that chooses how far back the area's climate-history charts reach")
        static let twentyFourHours = String(localized: "24 Hours", comment: "Picker option showing the last 24 hours of climate history")
        static let sevenDays = String(localized: "7 Days", comment: "Picker option showing the last 7 days of climate history")
        static let thirtyDays = String(localized: "30 Days", comment: "Picker option showing the last 30 days of climate history")
    }

    /// Maps each range to its picker label; the enum carries no display text.
    func rangeLabel(_ range: TimeRange) -> String {
        switch range {
        case .day: return Localization.twentyFourHours
        case .week: return Localization.sevenDays
        case .month: return Localization.thirtyDays
        }
    }

    /// Fixed, readable height shared by both plots so neither sizes to the container.
    static let plotHeight: CGFloat = 200
}

#if DEBUG
import SwiftData

/// Preview-only provider: a short synthetic 24-hour series for any sensor.
fileprivate final class StubHistoryProvider: SensorHistoryProviding {
    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        let now = Date()
        let start = now.addingTimeInterval(-24 * 60 * 60)
        let step = now.timeIntervalSince(start) / 4
        return [19.5, 20.2, 21.0, 20.6, 19.8].enumerated().map { index, mean in
            let from = start.addingTimeInterval(TimeInterval(index) * step)
            return ClimateSample(start: from, end: from.addingTimeInterval(300), mean: mean)
        }
    }
}

fileprivate struct PreviewClimateHistory: View {
    var body: some View {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, ScriptEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self,
            BinarySensorEntity.self, ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let context = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ).mainContext

        let area = AreaEntity(areaId: "preview.lobby", name: "Lobby")
        let temperature = SensorEntity(entityId: "sensor.lobby.temperature", name: "Temperature",
                                       state: "20", deviceClass: "temperature", unitOfMeasurement: "°C")
        let humidity = SensorEntity(entityId: "sensor.lobby.humidity", name: "Humidity",
                                    state: "47", deviceClass: "humidity", unitOfMeasurement: "%")
        temperature.area = area
        humidity.area = area
        context.insert(area)
        context.insert(temperature)
        context.insert(humidity)

        let viewModel = AreaClimateHistoryViewModel(area: area, provider: StubHistoryProvider())
        return AreaClimateHistoryView(viewModel: viewModel, areaName: area.name)
    }
}

#Preview {
    PreviewClimateHistory()
}

#endif
