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
        provider.result = samples(20.0)
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

    // MARK: - Superseded fetches

    /// A fetch outlived by the user's next selection must not replace the current chart.
    @Test
    func request_rangeSwitchedBeforeSettling_keepsTheCurrentlySelectedSeries() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        /**
         The week fetch blocks until released; the day fetch settles at once,
         standing in for the range the user switches to.
         */
        let provider = GatedHistoryProvider(
            gatedRange: .week,
            results: [.day: samples(20.0), .week: samples(21.0, 22.0)]
        )
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        let weekLoad = Task { await viewModel.load() }
        while provider.requests.last?.range != .week { await Task.yield() }

        // The user gives up on the week and the day range settles from a fresh fetch.
        viewModel.selectedRange = .day
        await viewModel.load()

        provider.release()
        await weekLoad.value

        guard case let .loaded(daySeries) = viewModel.series else {
            Issue.record("the day series was replaced by \(viewModel.series)")
            return
        }
        #expect(daySeries.samples.count == 1)
        #expect(daySeries.samples.last?.mean == 20.0)
        #expect(viewModel.isLoading == false)
    }

    /// A superseded outcome is cached, so re-selecting its range issues no request.
    @Test
    func request_rangeSwitchedBeforeSettling_cachesTheOutcomeWithoutRefetching() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = GatedHistoryProvider(
            gatedRange: .week,
            results: [.day: samples(20.0), .week: samples(21.0, 22.0)]
        )
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        viewModel.selectedRange = .week
        let weekLoad = Task { await viewModel.load() }
        while provider.requests.last?.range != .week { await Task.yield() }

        viewModel.selectedRange = .day
        await viewModel.load()

        provider.release()
        await weekLoad.value
        #expect(provider.requests.filter { $0.range == .week }.count == 1)

        // The week settled into the cache, so re-selecting the range renders without a request.
        viewModel.selectedRange = .week
        await viewModel.load()

        #expect(provider.requests.filter { $0.range == .week }.count == 1)
        guard case let .loaded(weekSeries) = viewModel.series else {
            Issue.record("expected the cached week series, got \(viewModel.series)")
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

        // One bucket at [1000, 1300): every position maps onto its only start, 1000.
        viewModel.selectedPosition = 0.5

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

        // Starts run 1000...1600, so position 0.5 is 1300 — the middle bucket's own start.
        viewModel.selectedPosition = 0.5

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

        // Position 1 is 1600, the end of the [1300, 1600) bucket, so it resolves the next one.
        viewModel.selectedPosition = 1.0

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

        // Starts run 1000...1600, so position 0.75 is 1450 — inside the gap.
        viewModel.selectedPosition = 0.75

        // A gap yields a readout with no sample, not a nil readout.
        let readout = viewModel.readout
        #expect(readout != nil)
        #expect(readout?.mean == nil)
        #expect(readout?.interval == nil)
    }

    /// Clearing the scrub position falls back to the latest reading, which is the idle headline.
    @Test
    func clearingSelectionFallsBackToTheLatestReading() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.0))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        viewModel.selectedPosition = 0.5
        #expect(viewModel.readout?.mean != nil)

        viewModel.selectedPosition = nil
        #expect(viewModel.readout?.mean == 20.0)
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

        viewModel.selectedPosition = 0.5
        #expect(viewModel.readout == nil)
    }

    // MARK: - date(atPosition:)

    /// A series that hasn't loaded resolves no date, whatever the position.
    @Test
    func date_loadingSeries_returnsNil() {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: MockSensorHistoryProvider())

        #expect(viewModel.date(atPosition: 0) == nil)
        #expect(viewModel.date(atPosition: 0.5) == nil)
        #expect(viewModel.date(atPosition: 1) == nil)
    }

    /// A failed series resolves no date, so the axis never labels an instant it can't back.
    @Test
    func date_failedSeries_returnsNil() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case .failed = viewModel.series else {
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }
        #expect(viewModel.date(atPosition: 0.5) == nil)
    }

    /// A settled no-history series is not loaded, so it resolves no date either.
    @Test
    func date_noRecordedHistorySeries_returnsNil() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(SensorHistoryError.noRecordedHistory)]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case .noRecordedHistory = viewModel.series else {
            Issue.record("series expected noRecordedHistory, got \(viewModel.series)")
            return
        }
        #expect(viewModel.date(atPosition: 0.5) == nil)
    }

    /// An empty window settles as `.noRecordedHistory`, so no position stands for a date.
    @Test
    func date_emptyWindow_returnsNil() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        #expect(viewModel.date(atPosition: 0) == nil)
        #expect(viewModel.date(atPosition: 1) == nil)
    }

    /// A single sample has no span to interpolate across, so every position stands for its start.
    @Test
    func date_singleSample_mapsEveryPositionToItsStart() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.0))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        let expected = Date(timeIntervalSince1970: 1000)
        for position in [0.0, 0.25, 0.5, 0.9, 1.0, 1.5] {
            #expect(viewModel.date(atPosition: position) == expected)
        }
    }

    /// The scrub range's edges stand for the series' first and last sample starts.
    @Test
    func date_positionsZeroAndOne_mapToFirstAndLastSampleStarts() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(10, 20, 30))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        #expect(viewModel.date(atPosition: 0) == Date(timeIntervalSince1970: 1000))
        #expect(viewModel.date(atPosition: 1) == Date(timeIntervalSince1970: 1600))
    }

    /// A position outside 0...1 clamps to the nearest edge, so the index can never walk off the samples.
    @Test
    func date_positionOutsideDomain_clampsToNearestSeriesEdge() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(10, 20, 30))]
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        #expect(viewModel.date(atPosition: -1) == Date(timeIntervalSince1970: 1000))
        #expect(viewModel.date(atPosition: 1.5) == Date(timeIntervalSince1970: 1600))
    }

    /**
     Unevenly spaced starts are where an index-linear and a time-linear walk disagree, so every
     curve point's date must survive a round trip through `date(atPosition:)`.
    */
    @Test
    func date_unevenlySpacedSamples_matchesTheCurvePointDates() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let base = Date(timeIntervalSince1970: 1000)
        let unevenSamples = [
            ClimateSample(start: base.addingTimeInterval(0), end: base.addingTimeInterval(300), mean: 20),
            ClimateSample(start: base.addingTimeInterval(300), end: base.addingTimeInterval(600), mean: 21),
            ClimateSample(start: base.addingTimeInterval(600), end: base.addingTimeInterval(900), mean: 22),
            ClimateSample(start: base.addingTimeInterval(86_400), end: base.addingTimeInterval(86_700), mean: 23),
        ]

        let provider = MockSensorHistoryProvider()
        provider.result = unevenSamples
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case let .loaded(loaded) = viewModel.series else {
            Issue.record("series expected loaded, got \(viewModel.series)")
            return
        }
        #expect(loaded.samples == unevenSamples)

        // Positions past the gap land between the last two starts, where the two walks diverge.
        for point in ClimateCurve.points(for: unevenSamples) {
            #expect(viewModel.date(atPosition: point.position) == point.date)
        }
    }

    // MARK: - Sparse series

    @Test
    func load_emptyWindow_reportsNoRecordedHistoryRatherThanABlankChart() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        guard case .noRecordedHistory = viewModel.series else {
            Issue.record("series expected noRecordedHistory, got \(viewModel.series)")
            return
        }
        #expect(viewModel.curveRuns.isEmpty)
    }

    @Test
    func load_singleSample_keepsOnePlottablePoint() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = samples(21.5)
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        // The chart marks a lone run rather than drawing a line, so the point must survive.
        #expect(viewModel.curveRuns.flatMap { $0 }.count == 1)
        #expect(viewModel.readout?.mean == 21.5)
    }

    // MARK: - Value domain

    @Test
    func load_spikeBetweenResampledPositions_framesTheDomainOnTheDrawnCurve() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        // 200 buckets, one spike no resampled position lands on, so the curve never reaches it.
        var means = Array(repeating: 20.0, count: 200)
        means[52] = 100
        let base = Date(timeIntervalSince1970: 1000)
        let spiked = means.enumerated().map { index, mean in
            let start = base.addingTimeInterval(TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: mean)
        }

        let provider = MockSensorHistoryProvider()
        provider.result = spiked
        let viewModel = AreaClimateHistoryViewModel(sensor: temperature, fallbackUnit: "°", provider: provider)

        await viewModel.load()

        let drawn = viewModel.curveRuns.flatMap { $0 }.map(\.value)
        #expect(drawn.max() ?? 0 < 100)
        #expect(viewModel.valueDomain == ClimateSampleYDomain.domain(forValues: drawn))
        #expect(viewModel.valueDomain.upperBound < 100)
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
