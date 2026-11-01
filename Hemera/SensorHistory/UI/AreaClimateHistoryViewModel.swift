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

    private(set) var series: SeriesState {
        didSet { rebuildCurve() }
    }

    /// The resampled curve, split where recording stopped — the shape the chart draws.
    private(set) var curveRuns: [[ClimateCurvePoint]] = []

    /// Framed on the data so a small real variation still reads as a curve.
    private(set) var valueDomain: ClosedRange<Double> = 0...1

    /// Whether a range's fetch is in flight, separate from `series` so a chart can stay while it loads.
    var isLoading: Bool { inFlightRequests > 0 }

    /// Range the user has chosen; changing it triggers a load of that window.
    var selectedRange: TimeRange = .day {
        // A position means nothing in a window the user is no longer looking at.
        didSet { selectedPosition = nil }
    }

    /// Where the user is scrubbing, 0...1 across the range. `nil` means nothing is selected.
    var selectedPosition: Double?

    var readout: Readout? { readout(for: series) }

    /// The curve point under the scrub, or `nil` in a gap, so no dot is drawn over nothing.
    var selectedPoint: ClimateCurvePoint? {
        guard let selectedPosition, readout?.mean != nil else { return nil }
        return curveRuns
            .flatMap { $0 }
            .min { abs($0.position - selectedPosition) < abs($1.position - selectedPosition) }
    }

    private let provider: any SensorHistoryProviding
    private let sensor: SensorEntity
    private let fallbackUnit: String

    /**
     A settled-success outcome per range, cached for this instance's life only.
     A `.failed` is never stored, so a transient error can't poison a range.
     */
    private var cache: [TimeRange: SeriesState] = [:]

    /// The number of range fetches in flight; `isLoading` is derived from it.
    private var inFlightRequests = 0

    init(sensor: SensorEntity, fallbackUnit: String, provider: any SensorHistoryProviding) {
        self.sensor = sensor
        self.fallbackUnit = fallbackUnit
        self.provider = provider
        series = .loading
    }

    /// The moment a scrub position stands for, used for the readout and the axis labels.
    func date(atPosition position: Double) -> Date? {
        guard case let .loaded(series) = series,
              let first = series.samples.first
        else { return nil }
        let samples = series.samples
        guard samples.count > 1 else { return first.start }
        // A chartXSelection value can land marginally outside 0...1; clamping keeps the index valid.
        let clamped = min(max(position, 0), 1)
        let exact = clamped * Double(samples.count - 1)
        let lower = samples[Int(exact.rounded(.down))]
        let upper = samples[Int(exact.rounded(.up))]
        let fraction = exact - exact.rounded(.down)
        return lower.start.addingTimeInterval(upper.start.timeIntervalSince(lower.start) * fraction)
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
        inFlightRequests += 1
        defer { inFlightRequests -= 1 }
        let outcome = await fetch(range: range)
        if Self.isCacheable(outcome) { cache[range] = outcome }
        // The chart shows the selected range; a moved-on outcome must not replace it.
        if range == selectedRange { series = outcome }
    }

    /**
     The sample at the selected position, or `nil` when nothing is selected or the
     series isn't loaded; a gap yields a readout with no sample fields.
     */
    private func readout(for state: SeriesState) -> Readout? {
        guard case let .loaded(series) = state else { return nil }

        guard let position = selectedPosition, let date = date(atPosition: position) else {
            // Nothing scrubbed: the headline shows the latest reading.
            guard let latest = series.samples.last else { return nil }
            return Readout(
                sensorName: series.sensorName,
                unit: series.unit,
                mean: latest.mean,
                interval: latest.start..<latest.end
            )
        }

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

    private func rebuildCurve() {
        guard case let .loaded(loaded) = series else {
            curveRuns = []
            valueDomain = 0...1
            return
        }
        curveRuns = ClimateCurve.runs(for: loaded.samples)
        valueDomain = ClimateSampleYDomain.domain(forValues: curveRuns.flatMap { $0 }.map(\.value))
    }

    private func fetch(range: TimeRange) async -> SeriesState {
        do {
            let samples = try await provider.history(forEntityId: sensor.entityId, range: range)
            // An empty window has nothing to draw, and a blank chart reads as a failure.
            guard !samples.isEmpty else { return .noRecordedHistory }
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
