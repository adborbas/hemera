import Foundation

/**
 Maps a settled run of samples, turning a 0...1 scrub position into a date and a reading.
 */
struct ClimateScrub: Sendable {

    let samples: [ClimateSample]

    /// The moment a scrub position stands for, or `nil` when there is nothing to interpolate.
    func date(atPosition position: Double) -> Date? {
        ClimateCurve.date(atPosition: position, in: samples)
    }

    /// The sample under a position on its half-open `start..<end`, or `nil` in a recording gap.
    func sample(atPosition position: Double) -> ClimateSample? {
        guard let date = date(atPosition: position) else { return nil }
        return samples.first(where: { $0.start <= date && date < $0.end })
    }
}
