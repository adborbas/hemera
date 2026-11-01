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
