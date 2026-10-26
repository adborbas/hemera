import Foundation
import SwiftData
import Testing
@testable import Hemera

private struct GenericHistoryError: Error {}

@MainActor
struct AreaClimateHistoryViewModelTests {

    // MARK: - Setup

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, ScriptEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self,
            BinarySensorEntity.self, ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - load

    @Test
    func load_withBothSensors_andProviderReturnsSamples_bothSeriesLoaded() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")
        let tempSamples = samples(20.0, 21.0)
        let humiditySamples = samples(45.0, 46.5)

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .samples(tempSamples),
            "sensor.lobby.humidity": .samples(humiditySamples),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        if case let .loaded(series) = viewModel.temperature {
            #expect(series.sensorName == "Temperature")
            #expect(series.unit == "°C")
            #expect(series.samples == tempSamples)
        } else {
            Issue.record("temperature expected to be loaded, got \(viewModel.temperature)")
        }
        if case let .loaded(series) = viewModel.humidity {
            #expect(series.sensorName == "Humidity")
            #expect(series.unit == "%")
            #expect(series.samples == humiditySamples)
        } else {
            Issue.record("humidity expected to be loaded, got \(viewModel.humidity)")
        }
    }

    @Test
    func load_withBothSensors_asksForBothEntityIdsInDayRange() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" && $0.range == .day })
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.humidity" && $0.range == .day })
    }

    @Test
    func load_temperatureThrowsNoRecordedHistory_humidityStillLoaded() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")
        let humiditySamples = samples(45.0)

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .failure(SensorHistoryError.noRecordedHistory),
            "sensor.lobby.humidity": .samples(humiditySamples),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case .noRecordedHistory = viewModel.temperature else {
            Issue.record("temperature expected noRecordedHistory, got \(viewModel.temperature)")
            return
        }
        if case let .loaded(series) = viewModel.humidity {
            #expect(series.samples == humiditySamples)
        } else {
            Issue.record("humidity expected to be loaded, got \(viewModel.humidity)")
        }
    }

    @Test
    func load_withGenericError_mapsToFailedNotNoRecordedHistory() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case .failed = viewModel.temperature else {
            // A generic error must surface as `.failed`, never `.noRecordedHistory`.
            Issue.record("temperature expected failed, got \(viewModel.temperature)")
            return
        }
    }

    @Test
    func load_areaWithNoHumiditySensor_humidityUnavailableAndNeverFetched() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: provider)

        await viewModel.load()

        guard case .unavailable = viewModel.humidity else {
            Issue.record("humidity expected unavailable, got \(viewModel.humidity)")
            return
        }
        // A measurement with no sensor is never fetched.
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.humidity" } == false)
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" })
    }

    @Test
    func load_withNilUnits_fallsBackToDefaults() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: nil)
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: nil)

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case let .loaded(series) = viewModel.temperature else {
            Issue.record("temperature expected loaded, got \(viewModel.temperature)")
            return
        }
        #expect(series.unit == "°")
        guard case let .loaded(series) = viewModel.humidity else {
            Issue.record("humidity expected loaded, got \(viewModel.humidity)")
            return
        }
        #expect(series.unit == "%")
    }

    // MARK: - Helpers

    private func sensor(_ entityId: String, name: String, deviceClass: String, unit: String?) -> SensorEntity {
        SensorEntity(entityId: entityId, name: name, state: "0", deviceClass: deviceClass, unitOfMeasurement: unit)
    }

    private func area(with sensors: [SensorEntity], in context: ModelContext) -> AreaEntity {
        let created = AreaEntity(areaId: "area", name: "Area")
        sensors.forEach { $0.area = created }
        context.insert(created)
        sensors.forEach(context.insert)
        return created
    }

    private func samples(_ means: Double...) -> [ClimateSample] {
        means.enumerated().map { index, value in
            let start = Date(timeIntervalSince1970: 1000 + TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: value)
        }
    }
}
