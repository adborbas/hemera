import Foundation

/// A sample resampled onto a fixed position, so two ranges can be charted as the same line.
struct ClimateCurvePoint: Identifiable, Equatable {
    let id: Int
    /// 0 at the start of the range, 1 at its end.
    let position: Double
    let date: Date
    let value: Double
}

/**
 Resamples a series onto fixed positions. Swift Charts interpolates only between marks sharing an
 identity, so equal positions are what let one range's line morph into the next.
*/
enum ClimateCurve {

    static let pointCount = 90

    static func points(for samples: [ClimateSample], count: Int = pointCount) -> [ClimateCurvePoint] {
        guard samples.count > 1, count > 1 else {
            return samples.prefix(1).map {
                ClimateCurvePoint(id: 0, position: 0, date: $0.start, value: $0.mean)
            }
        }

        return (0..<count).map { index in
            let position = Double(index) / Double(count - 1)
            let exact = position * Double(samples.count - 1)
            let lower = samples[Int(exact.rounded(.down))]
            let upper = samples[Int(exact.rounded(.up))]
            let fraction = exact - exact.rounded(.down)

            return ClimateCurvePoint(
                id: index,
                position: position,
                date: lower.start.addingTimeInterval(upper.start.timeIntervalSince(lower.start) * fraction),
                value: lower.mean + (upper.mean - lower.mean) * fraction
            )
        }
    }

    /**
     The curve split where recording stopped: interpolated points inside a gap are dropped, so an
     outage reads as a break. Survivors keep their id and position, which the morph depends on.
     */
    static func runs(for samples: [ClimateSample], count: Int = pointCount) -> [[ClimateCurvePoint]] {
        let points = points(for: samples, count: count)
        guard !points.isEmpty else { return [] }

        // Gap spans between runs: from one run's last sample end to the next run's first start.
        let sampleRuns = ClimateSampleRuns.split(samples)
        let gaps: [(start: Date, end: Date)] = zip(sampleRuns, sampleRuns.dropFirst()).compactMap { pair in
            guard let gapStart = pair.0.last?.end, let gapEnd = pair.1.first?.start else { return nil }
            return (start: gapStart, end: gapEnd)
        }

        var result: [[ClimateCurvePoint]] = []
        var current: [ClimateCurvePoint] = []

        for point in points {
            // Strictly inside a gap means interpolation across nothing, so the line breaks there.
            let isGap = gaps.contains { $0.start < point.date && point.date < $0.end }
            if isGap {
                if !current.isEmpty {
                    result.append(current)
                    current = []
                }
            } else {
                current.append(point)
            }
        }

        if !current.isEmpty { result.append(current) }
        return result
    }
}
