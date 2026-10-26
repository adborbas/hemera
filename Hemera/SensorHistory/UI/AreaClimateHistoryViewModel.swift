import Foundation

/**
 Loads climate history for one sensor over the selected range, caching each settled
 success for the presentation's life.
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
     The reading under the scrub position: its sensor name and unit, plus the sample.
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
    }

    private(set) var series: SeriesState

    /// Whether a range's fetch is in flight, separate from `series` so a chart can stay while it loads.
    private(set) var isLoading: Bool = false

    /// Range the user has chosen; changing it triggers a load of that window.
    var selectedRange: TimeRange = .day

    /// The scrub position the chart reads from; `nil` means nothing is selected.
    var selectedDate: Date?

    var readout: Readout? { readout(for: series) }

    private let provider: any SensorHistoryProviding
    private let sensor: SensorEntity
    private let fallbackUnit: String

    /**
     A settled-success outcome per range, cached for this instance's life only.
     A `.failed` is never stored, so a transient error can't poison a range.
     */
    private var cache: [TimeRange: SeriesState] = [:]

    init(sensor: SensorEntity, fallbackUnit: String, provider: any SensorHistoryProviding) {
        self.sensor = sensor
        self.fallbackUnit = fallbackUnit
        self.provider = provider
        series = .loading
    }

    // MARK: - Loading

    /**
     Loads the series for the selected range. A range already settled in this
     presentation renders from cache and issues no request.
     */
    func load() async {
        let range = selectedRange
        if let cached = cache[range] {
            series = cached
            return
        }
        await request(range: range)
    }

    /**
     Re-requests the selected range, ignoring the cache: a `.failed` is never
     stored, so a retry genuinely re-fetches the sensor's history.
     */
    func retry() async {
        await request(range: selectedRange)
    }

    // MARK: - Private

    /**
     Fetches and stores an outcome for a range, flagging the transfer as in
     flight and caching only the settled states that `isCacheable` keeps.
     */
    private func request(range: TimeRange) async {
        isLoading = true
        defer { isLoading = false }
        let outcome = await fetch(range: range)
        series = outcome
        if Self.isCacheable(outcome) { cache[range] = outcome }
    }

    /**
     The sample at the selected position, or `nil` when nothing is selected or the
     series isn't loaded; a gap yields a readout with no sample fields.
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

    private func fetch(range: TimeRange) async -> SeriesState {
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
        case .loading, .failed: return false
        }
    }
}
