import Foundation

/**
 Loads the last day of climate history for an area's representative temperature and
 humidity sensors, keeping each measurement's outcome explicit.
 */
@Observable
@MainActor
final class AreaClimateHistoryViewModel {

    struct ClimateSeries {
        let sensorName: String
        let unit: String
        let samples: [ClimateSample]
    }

    enum SeriesState {
        case loading
        case loaded(ClimateSeries)
        case noRecordedHistory
        case failed
        case unavailable
    }

    private(set) var temperature: SeriesState
    private(set) var humidity: SeriesState

    private let provider: any SensorHistoryProviding
    private let temperatureSensor: SensorEntity?
    private let humiditySensor: SensorEntity?

    init(area: AreaEntity, provider: any SensorHistoryProviding) {
        self.provider = provider
        let representatives = AreaDisplayHelpers.representativeSensors(from: area.sensors)
        self.temperatureSensor = representatives.temperature
        self.humiditySensor = representatives.humidity
        temperature = Self.initialSeriesState(for: representatives.temperature)
        humidity = Self.initialSeriesState(for: representatives.humidity)
    }

    // MARK: - Loading

    func load() async {
        // The two series fetch concurrently; one measurement's outcome never waits on the other.
        async let temperatureResult = fetchTemperature()
        async let humidityResult = fetchHumidity()
        temperature = await temperatureResult
        humidity = await humidityResult
    }

    // MARK: - Private

    private func fetchTemperature() async -> SeriesState {
        await fetch(temperatureSensor, fallbackUnit: "°")
    }

    private func fetchHumidity() async -> SeriesState {
        await fetch(humiditySensor, fallbackUnit: "%")
    }

    private func fetch(_ sensor: SensorEntity?, fallbackUnit: String) async -> SeriesState {
        guard let sensor else { return .unavailable }
        do {
            let samples = try await provider.history(forEntityId: sensor.entityId, range: .day)
            return .loaded(ClimateSeries(
                sensorName: sensor.name,
                unit: sensor.unitOfMeasurement ?? fallbackUnit,
                samples: samples
            ))
        } catch SensorHistoryError.noRecordedHistory {
            return .noRecordedHistory
        } catch {
            return .failed
        }
    }

    private static func initialSeriesState(for sensor: SensorEntity?) -> SeriesState {
        sensor == nil ? .unavailable : .loading
    }
}
