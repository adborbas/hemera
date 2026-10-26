import Charts
import Mortar
import SwiftUI

/// Stacked 24-hour temperature and humidity charts for an area's representative sensors.
struct AreaClimateHistoryView: View {

    var viewModel: AreaClimateHistoryViewModel
    let areaName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let now = Date()
        let window = now.addingTimeInterval(-Self.xWindowInterval)...now

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Mortar.Spacing.xl) {
                    plot(state: viewModel.temperature, color: .warm, window: window)
                    plot(state: viewModel.humidity, color: .cool, window: window)
                }
                .padding(Mortar.Spacing.l)
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
            .task { await viewModel.load() }
        }
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

                Chart {
                    ForEach(series.samples, id: \.start) { sample in
                        LineMark(
                            x: .value(Localization.timeAxis, sample.start),
                            y: .value(Localization.meanAxis, sample.mean)
                        )
                        .foregroundStyle(color)
                    }
                }
                .chartXScale(domain: window)
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
        static let timeAxis = String(localized: "Time", comment: "Horizontal axis key for a climate-history chart, over the past 24 hours")
        static let meanAxis = String(localized: "Mean", comment: "Vertical axis key for a climate-history chart, holding each bucket's mean")
    }

    /// Fixed, readable height shared by both plots so neither sizes to the container.
    static let plotHeight: CGFloat = 200

    /// 24 hours, the window both charts share — a vertical line means one instant.
    static let xWindowInterval: TimeInterval = 24 * 60 * 60
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
