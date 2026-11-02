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
            let date = Self.date(atPosition: position, in: samples) ?? samples[0].start
            return ClimateCurvePoint(
                id: index,
                position: position,
                date: date,
                value: Self.value(at: date, in: samples) ?? samples[0].mean
            )
        }
    }

    /**
     The moment a position stands for. Positions are spaced by elapsed time, so a recording gap
     takes the width it actually lasted rather than collapsing to the distance between two samples.
    */
    static func date(atPosition position: Double, in samples: [ClimateSample]) -> Date? {
        guard let first = samples.first, let last = samples.last else { return nil }
        guard samples.count > 1 else { return first.start }
        // A chartXSelection value can land marginally outside 0...1.
        let clamped = min(max(position, 0), 1)
        return first.start.addingTimeInterval(clamped * last.start.timeIntervalSince(first.start))
    }

    /// The reading at a moment, interpolated between the two samples bracketing it.
    static func value(at date: Date, in samples: [ClimateSample]) -> Double? {
        guard let first = samples.first else { return nil }
        guard let upperIndex = samples.firstIndex(where: { $0.start > date }) else {
            return samples.last?.mean
        }
        guard upperIndex > 0 else { return first.mean }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let span = upper.start.timeIntervalSince(lower.start)
        guard span > 0 else { return lower.mean }
        let fraction = date.timeIntervalSince(lower.start) / span
        return lower.mean + (upper.mean - lower.mean) * fraction
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
