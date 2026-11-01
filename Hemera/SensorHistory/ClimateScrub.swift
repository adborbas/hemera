import Foundation

/**
 Maps a settled run of samples, turning a 0...1 scrub position into a date and a reading.
 */
struct ClimateScrub: Sendable {

    let samples: [ClimateSample]

    /// The moment a scrub position stands for, or `nil` when there is nothing to interpolate.
    func date(atPosition position: Double) -> Date? {
        guard let first = samples.first else { return nil }
        guard samples.count > 1 else { return first.start }
        // A chartXSelection value can land marginally outside 0...1; clamping keeps the index valid.
        let clamped = min(max(position, 0), 1)
        let exact = clamped * Double(samples.count - 1)
        let lower = samples[Int(exact.rounded(.down))]
        let upper = samples[Int(exact.rounded(.up))]
        let fraction = exact - exact.rounded(.down)
        return lower.start.addingTimeInterval(upper.start.timeIntervalSince(lower.start) * fraction)
    }

    /// The sample under a position on its half-open `start..<end`, or `nil` in a recording gap.
    func sample(atPosition position: Double) -> ClimateSample? {
        guard let date = date(atPosition: position) else { return nil }
        return samples.first(where: { $0.start <= date && date < $0.end })
    }
}
