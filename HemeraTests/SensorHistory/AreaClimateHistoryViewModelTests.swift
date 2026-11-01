import Foundation
import Testing
@testable import Hemera

private struct GenericHistoryError: Error {}

/// A series the model cannot resolve a date from, however it got that way.
enum UnresolvableSeries: CaseIterable, Sendable {
    case neverLoaded
    case failed
    case absentStatistic
    case emptyWindow
}

@MainActor
struct AreaClimateHistoryViewModelTests {

    // MARK: - load

    @Test
    func load_withGenericError_mapsToFailedNotNoRecordedHistory() async {
        let (viewModel, _) = makeViewModel(outcome: .failure(GenericHistoryError()))

        await viewModel.load()

        // A generic error must surface as `.failed`, never `.noRecordedHistory`.
        expectFailed(viewModel)
    }

    @Test
    func load_withNilUnit_fallsBackToThePassedUnit() async {
        let (viewModel, _) = makeViewModel(result: samples(20.0), unit: nil)

        await viewModel.load()

        #expect(expectLoaded(viewModel)?.unit == "°")
    }

    // MARK: - Range selection and caching

    @Test
    func init_selectedRangeDefaultsToDay() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.selectedRange == .day)
    }

    @Test(arguments: [TimeRange.week, .month])
    func load_selectingARange_requestsThatRangeForTheSensor(_ range: TimeRange) async {
        let (viewModel, provider) = makeViewModel(result: [])

        viewModel.selectedRange = range
        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == Self.entityId && $0.range == range })
    }

    @Test
    func load_reselectingAFetchedRange_issuesNoFurtherRequest() async {
        let (viewModel, provider) = makeViewModel(result: [])

        viewModel.selectedRange = .week
        await viewModel.load()
        let requestCount = provider.requests.count

        // Selecting an already-fetched range again must render from cache without a request.
        await viewModel.load()

        #expect(provider.requests.count == requestCount)
    }

    @Test
    func load_rangeWhoseFetchFailed_isReRequestedOnReselect() async {
        let (viewModel, provider) = makeViewModel(outcome: .failure(GenericHistoryError()))

        viewModel.selectedRange = .week
        await viewModel.load()
        expectFailed(viewModel)
        let requestCount = provider.requests.count

        // A failure is never cached, so selecting the same range re-requests the sensor.
        await viewModel.load()

        #expect(provider.requests.count == requestCount + 1)
    }

    @Test
    func load_noRecordedHistoryOutcome_isCachedAndNotReRequested() async {
        let (viewModel, provider) = makeViewModel(outcome: .failure(SensorHistoryError.noRecordedHistory))

        viewModel.selectedRange = .week
        await viewModel.load()
        expectNoRecordedHistory(viewModel)
        let requestCount = provider.requests.count

        // A settled no-history outcome is cached, so re-selecting the range issues no request.
        await viewModel.load()

        #expect(provider.requests.count == requestCount)
    }

    // MARK: - In flight and retry

    /// The transfer flag is idle before a load and idle again once it settles.
    @Test
    func load_transferFlagIsIdleBeforeAndAfter() async {
        let (viewModel, _) = makeViewModel(result: [])

        #expect(viewModel.isLoading == false)

        await viewModel.load()

        #expect(viewModel.isLoading == false)
    }

    /// A failed range re-requests on retry, because a failure is never cached.
    @Test
    func load_aFailedRange_retryReRequestsTheSameRange() async {
        let (viewModel, provider) = makeViewModel(outcome: .failure(GenericHistoryError()))

        viewModel.selectedRange = .week
        await viewModel.load()
        expectFailed(viewModel)
        let afterFailure = provider.requests.count

        await viewModel.retry()

        // The retry genuinely re-fetches, so the recorded request count grows by one.
        #expect(provider.requests.count == afterFailure + 1)
        #expect(provider.requests.last?.range == .week)
    }

    /// A retry that succeeds swaps `.failed` for `.loaded`.
    @Test
    func load_aSuccessfulRetry_replacesFailedWithLoaded() async {
        let (viewModel, provider) = makeViewModel(outcome: .failure(GenericHistoryError()))

        viewModel.selectedRange = .week
        await viewModel.load()
        expectFailed(viewModel)

        // Flip the mock to succeed, then retry; the new result must replace `.failed`.
        provider.stubs = [Self.entityId: .samples(samples(20.5))]
        await viewModel.retry()

        #expect(expectLoaded(viewModel)?.samples.count == 1)
    }

    /// An absent statistic surfaces as `.noRecordedHistory`, never `.failed`.
    @Test
    func load_anAbsentStatistic_exposesNoRecordedHistoryNeverFailed() async {
        let (viewModel, _) = makeViewModel(outcome: .failure(SensorHistoryError.noRecordedHistory))

        viewModel.selectedRange = .week
        await viewModel.load()

        expectNoRecordedHistory(viewModel)
    }

    /// Selecting a range that fetches must not drop the chart to a loading spinner.
    @Test
    func load_aNewRangeInFlight_keepsThePreviouslyLoadedSeries() async {
        let (viewModel, provider) = makeGatedViewModel()

        await viewModel.load()
        #expect(expectLoaded(viewModel)?.samples.count == 1)

        viewModel.selectedRange = .week
        let loading = Task { await viewModel.load() }
        while provider.requests.last?.range != .week { await Task.yield() }

        // While the new range is in flight, the stale series stays and the flag is up.
        #expect(viewModel.isLoading == true)
        #expect(expectLoaded(viewModel)?.samples.count == 1)

        provider.release()
        await loading.value
        #expect(viewModel.isLoading == false)
        #expect(expectLoaded(viewModel)?.samples.count == 2)
    }

    // MARK: - Superseded fetches

    /// A fetch outlived by the user's next selection must not replace the current chart.
    @Test
    func request_rangeSwitchedBeforeSettling_keepsTheCurrentlySelectedSeries() async {
        let (viewModel, provider) = makeGatedViewModel()

        viewModel.selectedRange = .week
        let weekLoad = Task { await viewModel.load() }
        while provider.requests.last?.range != .week { await Task.yield() }

        // The user gives up on the week and the day range settles from a fresh fetch.
        viewModel.selectedRange = .day
        await viewModel.load()

        provider.release()
        await weekLoad.value

        let daySeries = expectLoaded(viewModel)
        #expect(daySeries?.samples.count == 1)
        #expect(daySeries?.samples.last?.mean == 20.0)
        #expect(viewModel.isLoading == false)
    }

    /// A superseded outcome is cached, so re-selecting its range issues no request.
    @Test
    func request_rangeSwitchedBeforeSettling_cachesTheOutcomeWithoutRefetching() async {
        let (viewModel, provider) = makeGatedViewModel()

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
        #expect(expectLoaded(viewModel)?.samples.count == 2)
    }

    // MARK: - Selection and readout

    /// Scrubbing inside a bucket reads out that bucket's mean.
    @Test
    func selectionInsideSampleResolvesThatSample() async {
        let (viewModel, _) = makeViewModel(outcome: .samples(samples(20.5)))

        await viewModel.load()

        // One bucket at [1000, 1300): every position maps onto its only start, 1000.
        viewModel.selectedPosition = 0.5

        #expect(viewModel.readout?.mean == 20.5)
    }

    /**
     The interval is half-open. Starts run 1000...1600, so position 0.5 is 1300 — the middle
     bucket's own start — and position 1 is 1600, the end of that bucket, which resolves the next.
    */
    @Test(arguments: [(0.5, 20.0), (1.0, 30.0)])
    func selectionOnABucketBoundaryResolvesTheHalfOpenInterval(_ position: Double, _ expected: Double) async {
        let (viewModel, _) = makeViewModel(outcome: .samples(samples(10, 20, 30)))

        await viewModel.load()

        viewModel.selectedPosition = position

        #expect(viewModel.readout?.mean == expected)
    }

    /// A date inside a recording gap resolves a readout with no mean.
    @Test
    func selectionInsideGapResolvesReadoutWithoutMean() async {
        // Temperature skips [1300, 1600); the position 1450 lands between its two buckets.
        let gapped = [
            ClimateSample(start: Date(timeIntervalSince1970: 1000), end: Date(timeIntervalSince1970: 1300), mean: 20.0),
            ClimateSample(start: Date(timeIntervalSince1970: 1600), end: Date(timeIntervalSince1970: 1900), mean: 22.0),
        ]
        let (viewModel, _) = makeViewModel(outcome: .samples(gapped))

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
        let (viewModel, _) = makeViewModel(outcome: .samples(samples(20.0)))

        await viewModel.load()

        viewModel.selectedPosition = 0.5
        #expect(viewModel.readout?.mean != nil)

        viewModel.selectedPosition = nil
        #expect(viewModel.readout?.mean == 20.0)
    }

    /// A failed series resolves no readout without crashing.
    @Test
    func selectionWithFailedSeriesResolvesNilWithoutCrashing() async {
        let (viewModel, _) = makeViewModel(outcome: .failure(GenericHistoryError()))

        await viewModel.load()
        expectFailed(viewModel)

        viewModel.selectedPosition = 0.5
        #expect(viewModel.readout == nil)
    }

    // MARK: - date(atPosition:)

    /**
     A series with no samples behind it resolves no date, however it got that way, so the axis
     never labels an instant it cannot back.
    */
    @Test(arguments: UnresolvableSeries.allCases)
    func date_seriesWithoutSamples_returnsNil(_ scenario: UnresolvableSeries) async {
        let (viewModel, _) = makeViewModel(for: scenario)

        if scenario != .neverLoaded { await viewModel.load() }

        #expect(viewModel.date(atPosition: 0) == nil)
        #expect(viewModel.date(atPosition: 0.5) == nil)
        #expect(viewModel.date(atPosition: 1) == nil)
    }

    /// A single sample has no span to interpolate across, so every position stands for its start.
    @Test
    func date_singleSample_mapsEveryPositionToItsStart() async {
        let (viewModel, _) = makeViewModel(outcome: .samples(samples(20.0)))

        await viewModel.load()

        let expected = Date(timeIntervalSince1970: 1000)
        for position in [0.0, 0.25, 0.5, 0.9, 1.0, 1.5] {
            #expect(viewModel.date(atPosition: position) == expected)
        }
    }

    /// The scrub range's edges stand for the series' first and last sample starts.
    @Test
    func date_positionsZeroAndOne_mapToFirstAndLastSampleStarts() async {
        let (viewModel, _) = makeViewModel(outcome: .samples(samples(10, 20, 30)))

        await viewModel.load()

        #expect(viewModel.date(atPosition: 0) == Date(timeIntervalSince1970: 1000))
        #expect(viewModel.date(atPosition: 1) == Date(timeIntervalSince1970: 1600))
    }

    /// A position outside 0...1 clamps, so the index can never walk off the samples.
    @Test
    func date_positionOutsideDomain_clampsToNearestSeriesEdge() async {
        let (viewModel, _) = makeViewModel(outcome: .samples(samples(10, 20, 30)))

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
        let base = Date(timeIntervalSince1970: 1000)
        let unevenSamples = [
            ClimateSample(start: base.addingTimeInterval(0), end: base.addingTimeInterval(300), mean: 20),
            ClimateSample(start: base.addingTimeInterval(300), end: base.addingTimeInterval(600), mean: 21),
            ClimateSample(start: base.addingTimeInterval(600), end: base.addingTimeInterval(900), mean: 22),
            ClimateSample(start: base.addingTimeInterval(86_400), end: base.addingTimeInterval(86_700), mean: 23),
        ]
        let (viewModel, _) = makeViewModel(result: unevenSamples)

        await viewModel.load()

        #expect(expectLoaded(viewModel)?.samples == unevenSamples)

        // Positions past the gap land between the last two starts, where the two walks diverge.
        for point in ClimateCurve.points(for: unevenSamples) {
            #expect(viewModel.date(atPosition: point.position) == point.date)
        }
    }

    // MARK: - Sparse series

    @Test
    func load_emptyWindow_reportsNoRecordedHistoryRatherThanABlankChart() async {
        let (viewModel, _) = makeViewModel(result: [])

        await viewModel.load()

        expectNoRecordedHistory(viewModel)
        #expect(viewModel.curveRuns.isEmpty)
    }

    @Test
    func load_singleSample_keepsOnePlottablePoint() async {
        let (viewModel, _) = makeViewModel(result: samples(21.5))

        await viewModel.load()

        // The chart marks a lone run rather than drawing a line, so the point must survive.
        #expect(viewModel.curveRuns.flatMap { $0 }.count == 1)
        #expect(viewModel.readout?.mean == 21.5)
    }

    // MARK: - Value domain

    @Test
    func load_spikeBetweenResampledPositions_framesTheDomainOnTheDrawnCurve() async {
        // 200 buckets, one spike no resampled position lands on, so the curve never reaches it.
        var means = Array(repeating: 20.0, count: 200)
        means[52] = 100
        let base = Date(timeIntervalSince1970: 1000)
        let spiked = means.enumerated().map { index, mean in
            let start = base.addingTimeInterval(TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: mean)
        }
        let (viewModel, _) = makeViewModel(result: spiked)

        await viewModel.load()

        let drawn = viewModel.curveRuns.flatMap { $0 }.map(\.value)
        #expect(drawn.max() ?? 0 < 100)
        #expect(viewModel.valueDomain == ClimateSampleYDomain.domain(forValues: drawn))
        #expect(viewModel.valueDomain.upperBound < 100)
    }

    // MARK: - Helpers

    private static let entityId = "sensor.lobby.temperature"

    /// The model over a mock, with the provider returned for tests that assert on its requests.
    private func makeViewModel(
        outcome: MockSensorHistoryProvider.Outcome? = nil,
        result: [ClimateSample]? = nil,
        unit: String? = "°C"
    ) -> (AreaClimateHistoryViewModel, MockSensorHistoryProvider) {
        let provider = MockSensorHistoryProvider()
        if let outcome { provider.stubs = [Self.entityId: outcome] }
        if let result { provider.result = result }
        return (makeViewModel(provider: provider, unit: unit), provider)
    }

    /// Configured for a series the model cannot resolve a date from.
    private func makeViewModel(
        for scenario: UnresolvableSeries
    ) -> (AreaClimateHistoryViewModel, MockSensorHistoryProvider) {
        switch scenario {
        case .neverLoaded: return makeViewModel()
        case .failed: return makeViewModel(outcome: .failure(GenericHistoryError()))
        case .absentStatistic: return makeViewModel(outcome: .failure(SensorHistoryError.noRecordedHistory))
        case .emptyWindow: return makeViewModel(result: [])
        }
    }

    /**
     The 24-hour range settles at once; the 7-day range blocks until released, so a test can
     read the model while its fetch is in flight.
    */
    private func makeGatedViewModel() -> (AreaClimateHistoryViewModel, GatedHistoryProvider) {
        let provider = GatedHistoryProvider(
            gatedRange: .week,
            results: [.day: samples(20.0), .week: samples(21.0, 22.0)]
        )
        return (makeViewModel(provider: provider, unit: "°C"), provider)
    }

    private func makeViewModel(
        provider: some SensorHistoryProviding,
        unit: String?
    ) -> AreaClimateHistoryViewModel {
        let sensor = SensorEntity(
            entityId: Self.entityId,
            name: "Temperature",
            state: "0",
            deviceClass: "temperature",
            unitOfMeasurement: unit
        )
        return AreaClimateHistoryViewModel(sensor: sensor, fallbackUnit: "°", provider: provider)
    }

    /// The loaded series, recording an issue that names what the model settled on instead.
    private func expectLoaded(_ viewModel: AreaClimateHistoryViewModel) -> AreaClimateHistoryViewModel.ClimateSeries? {
        guard case let .loaded(series) = viewModel.series else {
            Issue.record("series expected loaded, got \(viewModel.series)")
            return nil
        }
        return series
    }

    private func expectFailed(_ viewModel: AreaClimateHistoryViewModel) {
        guard case .failed = viewModel.series else {
            Issue.record("series expected failed, got \(viewModel.series)")
            return
        }
    }

    private func expectNoRecordedHistory(_ viewModel: AreaClimateHistoryViewModel) {
        guard case .noRecordedHistory = viewModel.series else {
            Issue.record("series expected noRecordedHistory, got \(viewModel.series)")
            return
        }
    }

    private func samples(_ means: Double...) -> [ClimateSample] {
        means.enumerated().map { index, value in
            let start = Date(timeIntervalSince1970: 1000 + TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: value)
        }
    }
}
