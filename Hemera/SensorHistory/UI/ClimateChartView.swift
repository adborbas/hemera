import SwiftUI
import Charts
import Mortar

/// Draws climate history as line runs over a 0...1 position axis, with an optional scrub marker.
struct ClimateChartView: View {
    let runs: [[ClimateCurvePoint]]
    let valueDomain: ClosedRange<Double>
    let color: Color
    /// Scrub position, 0...1. Nil when nothing is selected.
    @Binding var selectedPosition: Double?
    /// The point under the scrub, resolved by the caller.
    let selectedPoint: ClimateCurvePoint?
    let axisLabel: (Double) -> String

    var body: some View {
        Chart {
            ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                ForEach(run) { point in
                    LineMark(
                        x: .value("Position", point.position),
                        y: .value("Value", point.value),
                        series: .value("run", index)
                    )
                }
                .interpolationMethod(.monotone)
                .lineStyle(.init(lineWidth: 2, lineCap: .round))
                .foregroundStyle(color)

                // A run of one has no line between points, so it is marked or it draws nothing.
                if run.count == 1, let only = run.first {
                    PointMark(
                        x: .value("Position", only.position),
                        y: .value("Value", only.value)
                    )
                    .symbolSize(60)
                    .foregroundStyle(color)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Position", selectedPoint.position))
                    .foregroundStyle(color.opacity(0.35))
                    .lineStyle(.init(lineWidth: 1.5, dash: [4, 3]))

                PointMark(
                    x: .value("Position", selectedPoint.position),
                    y: .value("Value", selectedPoint.value)
                )
                .symbolSize(90)
                .foregroundStyle(color)
            }
        }
        .chartXScale(domain: 0...1)
        .chartYScale(domain: valueDomain)
        .chartXSelection(value: $selectedPosition)
        .chartXAxis {
            AxisMarks(values: Self.axisPositions) { value in
                AxisGridLine()
                AxisValueLabel(anchor: Self.labelAnchor(for: value.as(Double.self) ?? 0)) {
                    Text(axisLabel(value.as(Double.self) ?? 0))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing)
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .frame(maxHeight: .infinity)
        .animation(.smooth(duration: 0.40), value: runs.flatMap { $0 }.map(\.value))
    }

    private static let axisPositions: [Double] = [0.02, 0.5, 0.98]

    /**
     The end labels hang inward from their tick. Centred, the last one overlaps the trailing
     value labels and Swift Charts drops it rather than letting it collide.
    */
    private static func labelAnchor(for position: Double) -> UnitPoint {
        guard let first = axisPositions.first, let last = axisPositions.last else { return .top }
        if position <= first { return .topLeading }
        if position >= last { return .topTrailing }
        return .top
    }
}

#if DEBUG

#Preview("One run") {
    ClimateChartView(
        runs: [previewRun(from: 0, to: 1, base: 20, amplitude: 2.5)],
        valueDomain: 16...25,
        color: .warm,
        selectedPosition: .constant(nil),
        selectedPoint: nil,
        axisLabel: previewAxisLabel
    )
}

#Preview("Runs with a gap") {
    ClimateChartView(
        runs: [
            previewRun(from: 0, to: 0.45, base: 20, amplitude: 2.5),
            previewRun(from: 0.55, to: 1, base: 20, amplitude: 2.5, phase: 1.5)
        ],
        valueDomain: 16...25,
        color: .cool,
        selectedPosition: .constant(nil),
        selectedPoint: nil,
        axisLabel: previewAxisLabel
    )
}

#Preview("Scrub selection") {
    let run = previewRun(from: 0, to: 1, base: 20, amplitude: 2.5)
    let point = run[45]
    ClimateChartView(
        runs: [run],
        valueDomain: 16...25,
        color: .warm,
        selectedPosition: .constant(point.position),
        selectedPoint: point,
        axisLabel: previewAxisLabel
    )
}

/// Sine-shaped sample data for previews, spanning the given position range.
fileprivate func previewRun(
    from start: Double,
    to end: Double,
    base: Double,
    amplitude: Double,
    phase: Double = 0,
    count: Int = 90
) -> [ClimateCurvePoint] {
    guard count > 1 else { return [] }
    return (0..<count).map { index in
        let progress = Double(index) / Double(count - 1)
        let position = start + (end - start) * progress
        let value = base + amplitude * sin(4 * .pi * position + phase)
        return ClimateCurvePoint(
            id: index,
            position: position,
            date: .now.addingTimeInterval(position * 86_400),
            value: value
        )
    }
}

fileprivate func previewAxisLabel(_ position: Double) -> String {
    String(format: "%02d:00", Int(position * 24))
}

#endif
