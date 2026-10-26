import Foundation

/**
 Loads climate history for an area's representative temperature and humidity sensors
 over the selected range, caching each settled success for the presentation's life.
 */
@Observable
@MainActor
final class AreaClimateHistoryViewModel {

    struct ClimateSeries {
        let sensorName: String
        let unit: String
        let samples: [ClimateSample]
    }

    /**
     One measurement at the scrub position: its sensor name and unit, plus the sample under it.
     `mean` and `interval` are `nil` together when it lands in a gap or the series isn't loaded.
     */
    struct Readout {
        let sensorName: String
        let unit: String
        let mean: Double?
        let interval: Range<Date>?
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

    /// Range the user has chosen; changing it triggers a load of that window.
    var selectedRange: TimeRange = .day

    /// The scrub position both charts read from; `nil` means nothing is selected.
    var selectedDate: Date?

    var temperatureReadout: Readout? { readout(for: temperature) }
    var humidityReadout: Readout? { readout(for: humidity) }

    private let provider: any SensorHistoryProviding
    private let temperatureSensor: SensorEntity?
    private let humiditySensor: SensorEntity?

    /**
     Settled-success outcomes per range, cached for this instance's life only.
     A `.failed` is never stored, so a transient error can't poison a range.
     */
    private var temperatureCache: [TimeRange: SeriesState] = [:]
    private var humidityCache: [TimeRange: SeriesState] = [:]

    init(area: AreaEntity, provider: any SensorHistoryProviding) {
        self.provider = provider
        let representatives = AreaDisplayHelpers.representativeSensors(from: area.sensors)
        self.temperatureSensor = representatives.temperature
        self.humiditySensor = representatives.humidity
        temperature = Self.initialSeriesState(for: representatives.temperature)
        humidity = Self.initialSeriesState(for: representatives.humidity)
    }

    // MARK: - Loading

    /**
     Loads the two series for the selected range. A range already settled in this
     presentation renders from cache and issues no request; otherwise both fetch concurrently.
     */
    func load() async {
        let range = selectedRange
        let cachedTemperature = temperatureCache[range]
        let cachedHumidity = humidityCache[range]
        if let cachedTemperature, let cachedHumidity {
            temperature = cachedTemperature
            humidity = cachedHumidity
            return
        }

        // The two series fetch concurrently; one measurement's outcome never waits on the other.
        async let nextTemperature = resolve(temperatureSensor, unit: "°", cached: cachedTemperature, range: range)
        async let nextHumidity = resolve(humiditySensor, unit: "%", cached: cachedHumidity, range: range)

        let resolvedTemperature = await nextTemperature
        let resolvedHumidity = await nextHumidity
        temperature = resolvedTemperature
        humidity = resolvedHumidity

        if Self.isCacheable(resolvedTemperature) { temperatureCache[range] = resolvedTemperature }
        if Self.isCacheable(resolvedHumidity) { humidityCache[range] = resolvedHumidity }
    }

    // MARK: - Private

    /**
     Resolves the sample under the selected position for one measurement, or `nil` when
     nothing is selected, the series isn't loaded, or the position lands in a gap.
     */
    private func readout(for state: SeriesState) -> Readout? {
        guard let date = selectedDate, case let .loaded(series) = state else { return nil }
        // A sample is under the position on the half-open interval `start..<end`.
        guard let sample = series.samples.first(where: { $0.start <= date && date < $0.end }) else {
            return Readout(sensorName: series.sensorName, unit: series.unit, mean: nil, interval: nil)
        }
        return Readout(
            sensorName: series.sensorName,
            unit: series.unit,
            mean: sample.mean,
            interval: sample.start..<sample.end
        )
    }

    private func resolve(
        _ sensor: SensorEntity?,
        unit: String,
        cached: SeriesState?,
        range: TimeRange
    ) async -> SeriesState {
        if let cached { return cached }
        return await fetch(sensor, fallbackUnit: unit, range: range)
    }

    private func fetch(_ sensor: SensorEntity?, fallbackUnit: String, range: TimeRange) async -> SeriesState {
        guard let sensor else { return .unavailable }
        do {
            let samples = try await provider.history(forEntityId: sensor.entityId, range: range)
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

    /// Only settled successes are worth keeping; a `.failed` must stay re-fetchable.
    private static func isCacheable(_ state: SeriesState) -> Bool {
        switch state {
        case .loaded, .noRecordedHistory: return true
        case .loading, .failed, .unavailable: return false
        }
    }

    private static func initialSeriesState(for sensor: SensorEntity?) -> SeriesState {
        sensor == nil ? .unavailable : .loading
    }
}
