import Foundation
import Testing

@testable import Hemera

struct ClimateCurveTests {

    @Test
    func points_spansTheSeriesFromFirstSampleToLast() {
        let points = ClimateCurve.points(for: samples(10, 20, 30), count: 5)

        #expect(points.first?.position == 0)
        #expect(points.last?.position == 1)
        #expect(points.first?.value == 10)
        #expect(points.last?.value == 30)
    }

    @Test
    func points_betweenSamples_interpolatesRatherThanSnapping() {
        let points = ClimateCurve.points(for: samples(10, 20), count: 3)

        #expect(abs((points[1].value) - 15) < 0.0001)
    }

    @Test
    func points_fromDifferentLengthSeries_produceTheSameCount() {
        let short = ClimateCurve.points(for: samples(1, 2, 3), count: 40)
        let long = ClimateCurve.points(for: samples(Array(repeating: 1.0, count: 700)), count: 40)

        #expect(short.count == 40)
        #expect(long.count == 40)
        #expect(short.map(\.position) == long.map(\.position))
    }

    @Test
    func points_withSingleSample_returnsThatSampleWithoutCrashing() {
        let points = ClimateCurve.points(for: samples(21), count: 40)

        #expect(points.count == 1)
        #expect(points.first?.value == 21)
    }

    // MARK: - Helpers

    /**
     The whole point: a recording outage must take the width it actually lasted. Spaced by index,
     the midpoint would land on the third of five samples and the axis would misstate the day.
    */
    @Test
    func points_withARecordingGap_spacePositionsByElapsedTimeNotByIndex() {
        let base = Date(timeIntervalSince1970: 0)
        let gapped = [0.0, 300, 600, 86_400, 86_700].map {
            ClimateSample(start: base.addingTimeInterval($0), end: base.addingTimeInterval($0 + 300), mean: 20)
        }

        let midpoint = try! #require(ClimateCurve.date(atPosition: 0.5, in: gapped))

        // Half of the 86,700s the series spans, which is deep inside the outage.
        #expect(abs(midpoint.timeIntervalSince(base) - 43_350) < 0.001)
        #expect(midpoint > gapped[2].end)
        #expect(midpoint < gapped[3].start)
    }

    @Test
    func value_betweenTwoSamples_interpolatesOnElapsedTime() {
        let base = Date(timeIntervalSince1970: 0)
        let uneven = [
            ClimateSample(start: base, end: base.addingTimeInterval(300), mean: 10),
            ClimateSample(start: base.addingTimeInterval(1000), end: base.addingTimeInterval(1300), mean: 20)
        ]

        let quarter = ClimateCurve.value(at: base.addingTimeInterval(250), in: uneven)

        #expect(abs((quarter ?? 0) - 12.5) < 0.0001)
    }

    private func samples(_ means: Double...) -> [ClimateSample] {
        samples(means)
    }

    private func samples(_ means: [Double]) -> [ClimateSample] {
        means.enumerated().map { index, mean in
            let start = Date(timeIntervalSince1970: Double(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: mean)
        }
    }
}
