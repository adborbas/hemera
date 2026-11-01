import Foundation
import Testing
@testable import Hemera

@MainActor
struct ClimateSampleRunsTests {

    // MARK: - Fixtures

    /// One bucket whose `duration` is fixed, so gaps can be reasoned about absolutely.
    private func sample(at startSeconds: Double, duration: Double, mean: Double = 20.0) -> ClimateSample {
        let start = Date(timeIntervalSince1970: startSeconds)
        return ClimateSample(start: start, end: start.addingTimeInterval(duration), mean: mean)
    }

    // MARK: - Contiguity

    @Test
    func split_contiguousSeries_returnsOneRunHoldingEverySampleInOrder() {
        let samples = (0..<10).map { sample(at: 1000 + Double($0) * 300, duration: 300, mean: 20.0 + Double($0)) }

        let runs = ClimateSampleRuns.split(samples)

        #expect(runs.count == 1)
        #expect(runs[0].count == 10)
        #expect(runs[0].map(\.mean) == samples.map(\.mean))
    }

    // MARK: - Gaps

    @Test
    func split_sixHourHoleInFiveMinuteBuckets_splitsIntoTwoRunsWithNoSampleLostOrDuplicated() {
        let duration = 300.0
        let hole = 6.0 * 60 * 60
        let first = (0..<5).map { sample(at: 1000 + Double($0) * duration, duration: duration, mean: 20.0 + Double($0)) }
        let secondStart = 1000 + 5.0 * duration + hole
        let second = (0..<3).map { sample(at: secondStart + Double($0) * duration, duration: duration, mean: 30.0 + Double($0)) }
        let samples = first + second

        let runs = ClimateSampleRuns.split(samples)

        #expect(runs.count == 2)
        #expect(runs[0].count == 5)
        #expect(runs[1].count == 3)
        // Every original bucket survives the split exactly once, in order.
        #expect(runs.flatMap { $0 }.map(\.start) == samples.map(\.start))
    }

    @Test
    func split_thresholdIsRelative_sameAbsoluteGapSplitsFiveMinuteButNotDailyBuckets() {
        let fiveMinute = 300.0
        let daily = 86_400.0
        let hole = 6.0 * 60 * 60

        let short = [
            sample(at: 1000, duration: fiveMinute),
            sample(at: 1000 + fiveMinute + hole, duration: fiveMinute),
        ]
        let long = [
            sample(at: 1000, duration: daily),
            sample(at: 1000 + daily + hole, duration: daily),
        ]

        // 6 h dwarfs a five-minute threshold yet fits inside a daily one.
        #expect(ClimateSampleRuns.split(short).count == 2)
        #expect(ClimateSampleRuns.split(long).count == 1)
    }

    // MARK: - Edge cases

}
