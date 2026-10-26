import Foundation
import Testing
@testable import Hemera

private struct GenericHistoryError: Error {}

@MainActor
struct AreaClimateHistoryViewModelTests {

    // MARK: - load

    @Test
    func load_withGenericError_mapsToFailedNotNoRecordedHistory() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case .failed = viewModel.series else {
            // A generic error must surface as `.failed`, never `.noRecordedHistory`.
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }
    }

    @Test
    func load_withNilUnit_fallsBackToThePassedUnit() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: nil)

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case let .loaded(series) = viewModel.series else {
            Issue.record("series expected loaded, got \(viewModel.series)")
            return
        }
        #expect(series.unit == "°")
    }

    // MARK: - Range selection and caching

    @Test
    func init_selectedRangeDefaultsToDay() {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: MockSensorHistoryProvider())

        #expect(viewModel.selectedRange == .day)
    }

    @Test
    func load_selectingWeek_requestsWeekRangeForTheSensor() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" && $0.range == .week })
    }

    @Test
    func load_selectingMonth_requestsMonthRangeForTheSensor() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .month
        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" && $0.range == .month })
    }

    @Test
    func load_reselectingAFetchedRange_issuesNoFurtherRequest() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        let requestCount = provider.requests.count

        // Selecting an already-fetched range again must render from cache without a request.
        await viewModel.load()

        #expect(provider.requests.count == requestCount)
    }

    @Test
    func load_rangeWhoseFetchFailed_isReRequestedOnReselect() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        guard case .failed = viewModel.series else {
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }
        let requestCount = provider.requests.count

        // A failure is never cached, so selecting the same range re-requests the sensor.
        await viewModel.load()

        #expect(provider.requests.count == requestCount + 1)
    }

    @Test
    func load_noRecordedHistoryOutcome_isCachedAndNotReRequested() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(SensorHistoryError.noRecordedHistory)]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        guard case .noRecordedHistory = viewModel.series else {
            Issue.record("series expected noRecordedHistory, got \(viewModel.series)")
            return
        }
        let requestCount = provider.requests.count

        // A settled no-history outcome is cached, so re-selecting the range issues no request.
        await viewModel.load()

        #expect(provider.requests.count == requestCount)
    }

    // MARK: - In flight and retry

    /// The transfer flag is idle before a load and idle again once it settles.
    @Test
    func load_transferFlagIsIdleBeforeAndAfter() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        #expect(viewModel.isLoading == false)

        await viewModel.load()

        #expect(viewModel.isLoading == false)
    }

    /// A failed range re-requests on retry, because a failure is never cached.
    @Test
    func load_aFailedRange_retryReRequestsTheSameRange() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        guard case .failed = viewModel.series else {
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }
        let afterFailure = provider.requests.count

        await viewModel.retry()

        // The retry genuinely re-fetches, so the recorded request count grows by one.
        #expect(provider.requests.count == afterFailure + 1)
        #expect(provider.requests.last?.range == .week)
    }

    /// A retry that succeeds swaps `.failed` for `.loaded`.
    @Test
    func load_aSuccessfulRetry_replacesFailedWithLoaded() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        guard case .failed = viewModel.series else {
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }

        // Flip the mock to succeed, then retry; the new result must replace `.failed`.
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.5))]
        await viewModel.retry()

        guard case .loaded(let series) = viewModel.series else {
            Issue.record("series expected loaded after a successful retry, got \(viewModel.series)")
            return
        }
        #expect(series.samples.count == 1)
    }

    /// An absent statistic surfaces as `.noRecordedHistory`, never `.failed`.
    @Test
    func load_anAbsentStatistic_exposesNoRecordedHistoryNeverFailed() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(SensorHistoryError.noRecordedHistory)]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()

        // A guard passing proves the outcome is `.noRecordedHistory`, and thus not `.failed`.
        guard case .noRecordedHistory = viewModel.series else {
            Issue.record("an absent statistic must surface as .noRecordedHistory, got \(viewModel.series)")
            return
        }
    }

    /// Selecting a range that fetches must not drop the chart to a loading spinner.
    @Test
    func load_aNewRangeInFlight_keepsThePreviouslyLoadedSeries() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        /**
         The 24-hour range settles at once; the 7-day range blocks until released,
         so the test can read the model while its fetch is in flight.
         */
        let provider = GatedHistoryProvider(
            gatedRange: .week,
            results: [.day: samples(20.0), .week: samples(21.0, 22.0)]
        )
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()
        guard case .loaded(let daySeries) = viewModel.series else {
            Issue.record("expected the 24-hour range to settle, got \(viewModel.series)")
            return
        }
        #expect(daySeries.samples.count == 1)

        viewModel.selectedRange = .week
        let loading = Task { await viewModel.load() }
        while provider.requests.last?.range != .week { await Task.yield() }

        // While the new range is in flight, the stale series stays and the flag is up.
        #expect(viewModel.isLoading == true)
        guard case .loaded(let stale) = viewModel.series else {
            Issue.record("the loaded series dropped to \(viewModel.series) while a range was loading")
            return
        }
        #expect(stale.samples.count == 1)

        provider.release()
        await loading.value
        #expect(viewModel.isLoading == false)

        guard case .loaded(let weekSeries) = viewModel.series else {
            Issue.record("expected the 7-day range to settle, got \(viewModel.series)")
            return
        }
        #expect(weekSeries.samples.count == 2)
    }

    // MARK: - Selection and readout

    /// Scrubbing inside a bucket reads out that bucket's mean.
    @Test
    func selectionInsideSampleResolvesThatSample() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.5))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        // samples(_:) lays one 300s bucket at [1000, 1300); 1100 falls inside it.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)

        #expect(viewModel.readout?.mean == 20.5)
    }

    /// The interval is half-open: a bucket's own `start` resolves that bucket.
    @Test
    func selectionOnSampleStartResolvesThatSampleNotTheNext() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(10, 20, 30))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        // buckets are [1000, 1300)=10, [1300, 1600)=20, [1600, 1900)=30; 1300 is the middle start.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1300)

        #expect(viewModel.readout?.mean == 20)
    }

    /// The interval is half-open: a bucket's `end` does not resolve that bucket, it resolves the next.
    @Test
    func selectionOnSampleEndResolvesTheNextSample() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(10, 20, 30))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        // 1600 is the end of the [1300, 1600)=20 bucket, so it resolves the [1600, 1900)=30 bucket.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1600)

        #expect(viewModel.readout?.mean == 30)
    }

    /// A date inside a recording gap resolves a readout with no mean.
    @Test
    func selectionInsideGapResolvesReadoutWithoutMean() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        // Temperature skips [1300, 1600); the position 1450 lands between its two buckets.
        let temperatureSamples = [
            ClimateSample(start: Date(timeIntervalSince1970: 1000), end: Date(timeIntervalSince1970: 1300), mean: 20.0),
            ClimateSample(start: Date(timeIntervalSince1970: 1600), end: Date(timeIntervalSince1970: 1900), mean: 22.0),
        ]
        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(temperatureSamples)]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        viewModel.selectedDate = Date(timeIntervalSince1970: 1450)

        // A gap yields a readout with no sample, not a nil readout.
        let readout = viewModel.readout
        #expect(readout != nil)
        #expect(readout?.mean == nil)
        #expect(readout?.interval == nil)
    }

    /// A date outside every bucket resolves a readout with no mean.
    @Test
    func selectionOutsideLoadedSeriesResolvesNil() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.0))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        let outsideAfter = Date(timeIntervalSince1970: 5000)
        let outsideBefore = Date(timeIntervalSince1970: 500)
        viewModel.selectedDate = outsideAfter
        #expect(viewModel.readout?.mean == nil)
        viewModel.selectedDate = outsideBefore
        #expect(viewModel.readout?.mean == nil)
    }

    /// Clearing the scrub position leaves nothing to read.
    @Test
    func clearingSelectedDateLeavesNoReadout() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.0))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)
        #expect(viewModel.readout?.mean != nil)

        viewModel.selectedDate = nil
        #expect(viewModel.readout == nil)
    }

    /// A failed series resolves no readout without crashing.
    @Test
    func selectionWithFailedSeriesResolvesNilWithoutCrashing() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case .failed = viewModel.series else {
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }

        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)
        #expect(viewModel.readout == nil)
    }

    // MARK: - Helpers

    private func sensor(_ entityId: String, name: String, deviceClass: String, unit: String?) -> SensorEntity {
        SensorEntity(entityId: entityId, name: name, state: "0", deviceClass: deviceClass, unitOfMeasurement: unit)
    }

    private func samples(_ means: Double...) -> [ClimateSample] {
        means.enumerated().map { index, value in
            let start = Date(timeIntervalSince1970: 1000 + TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: value)
        }
    }
}

/// Blocks one range's request until released, so a test can read the model mid-fetch.
private final class GatedHistoryProvider: SensorHistoryProviding, @unchecked Sendable {

    struct Request { let entityId: String; let range: TimeRange }

    var requests: [Request] {
        withLock { _requests }
    }

    private let lock = NSLock()
    private var _requests: [Request] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var released = false
    private let gatedRange: TimeRange
    private let results: [TimeRange: [ClimateSample]]

    init(gatedRange: TimeRange, results: [TimeRange: [ClimateSample]]) {
        self.gatedRange = gatedRange
        self.results = results
    }

    /// Locking stays in synchronous helpers, away from the async path.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func register(_ continuation: CheckedContinuation<Void, Never>) {
        withLock {
            if released {
                continuation.resume()
            } else {
                gate = continuation
            }
        }
    }

    private func awaitGate() async {
        await withCheckedContinuation { continuation in
            register(continuation)
        }
    }

    /// Lets a blocked request finish, so a test can act while it was in flight.
    func release() {
        withLock {
            released = true
            gate?.resume()
            gate = nil
        }
    }

    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        withLock { _requests.append(Request(entityId: entityId, range: range)) }
        if range == gatedRange {
            await awaitGate()
        }
        return results[range] ?? []
    }
}
