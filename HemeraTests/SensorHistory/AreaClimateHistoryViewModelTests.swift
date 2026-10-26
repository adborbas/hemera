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
