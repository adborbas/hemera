import Accessibility
import Foundation
import SwiftUI

/**
 A sendable audio-graph descriptor built from a settled series, so VoiceOver hears
 the recorded values and never a point that the run split dropped.
*/
struct ClimateChartDescriptor: AXChartDescriptorRepresentable, Sendable {

    let title: String
    let summary: String
    let unit: String
    let range: TimeRange
    let window: ClosedRange<Date>
    let samples: [ClimateSample]
    let xAxisTitle: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let start = window.lowerBound.timeIntervalSinceReferenceDate
        let end = window.upperBound.timeIntervalSinceReferenceDate
        let means = samples.map(\.mean)

        let y: ClosedRange<Double>
        if let lo = means.min(), let hi = means.max() {
            y = lo...hi
        } else {
            y = 0...1
        }

        let xAxis = AXNumericDataAxisDescriptor(
            title: xAxisTitle,
            range: start...end,
            gridlinePositions: [],
            valueDescriptionProvider: {
                Self.time(range, Date(timeIntervalSinceReferenceDate: $0))
            }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: unit,
            range: y,
            gridlinePositions: [],
            valueDescriptionProvider: {
                $0.formatted(.number.precision(.fractionLength(1))) + unit
            }
        )

        // One series per run keeps each gap a break, and adds nothing where a sample is absent.
        var series: [AXDataSeriesDescriptor] = []
        for run in ClimateSampleRuns.split(samples) {
            let points = run.map { sample in
                AXDataPoint(
                    x: sample.start.timeIntervalSinceReferenceDate,
                    y: sample.mean,
                    label: pointLabel(sample)
                )
            }
            series.append(AXDataSeriesDescriptor(name: title, isContinuous: true, dataPoints: points))
        }

        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: series
        )
    }

    /// A sample's interval then its mean and unit, mirroring the scrub readout.
    private func pointLabel(_ sample: ClimateSample) -> String {
        let span = "\(Self.time(range, sample.start)) – \(Self.time(range, sample.end)) "
        return span + "\(sample.mean.formatted(.number.precision(.fractionLength(1))))\(unit)"
    }

    /// A time in the selected range's style; the day drops the date, the others keep it.
    private static func time(_ range: TimeRange, _ date: Date) -> String {
        switch range {
        case .day:
            return date.formatted(date: .omitted, time: .shortened)
        case .week, .month:
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}
