import Foundation
import Testing

@testable import Hemera

struct ClimateCurveRunsTests {

    // MARK: - Fixtures

    private func sample(at startSeconds: Double, duration: Double = 300, mean: Double = 20) -> ClimateSample {
        let start = Date(timeIntervalSince1970: startSeconds)
        return ClimateSample(start: start, end: start.addingTimeInterval(duration), mean: mean)
    }

    /// Ten contiguous five-minute buckets.
    private func gaplessSamples() -> [ClimateSample] {
        (0..<10).map { sample(at: Double($0) * 300) }
    }

    /// Five five-minute buckets, a six-hour hole, then three more — one recording outage.
    private func gappedSamples() -> [ClimateSample] {
        let before = [0.0, 300, 600, 900, 1200].map { sample(at: $0, mean: 20) }
        let after = [21600.0, 21900, 22200].map { sample(at: $0, mean: 30) }
        return before + after
    }

    // MARK: - Tests

    @Test
    func runs_gaplessSeries_returnsOneRunHoldingEveryPoint() {
        let samples = gaplessSamples()
        let runs = ClimateCurve.runs(for: samples)

        #expect(runs.count == 1)
        #expect(runs[0] == ClimateCurve.points(for: samples))
    }

    @Test
    func runs_singleOutage_returnsTwoRuns() {
        let runs = ClimateCurve.runs(for: gappedSamples())

        #expect(runs.count == 2)
    }

    @Test
    func runs_singleOutage_noSurvivingPointSitsInsideTheGap() {
        let allPoints = ClimateCurve.runs(for: gappedSamples()).flatMap { $0 }
        let gapStart = Date(timeIntervalSince1970: 1500)
        let gapEnd = Date(timeIntervalSince1970: 21600)

        for point in allPoints {
            #expect(!(point.date > gapStart && point.date < gapEnd))
        }
    }

    @Test
    func runs_singleOutage_survivorsKeepTheIdAndPositionTheyHadBefore() {
        let samples = gappedSamples()
        let points = ClimateCurve.points(for: samples)
        let gapStart = Date(timeIntervalSince1970: 1500)
        let gapEnd = Date(timeIntervalSince1970: 21600)
        let expected = points.filter { !($0.date > gapStart && $0.date < gapEnd) }

        let survivors = ClimateCurve.runs(for: samples).flatMap { $0 }

        #expect(survivors == expected)
    }

    @Test
    func runs_emptyInput_returnsNoRuns() {
        #expect(ClimateCurve.runs(for: []).isEmpty)
    }
}
