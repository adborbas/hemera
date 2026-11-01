import Foundation

/// The mean over `start...end` — an aggregate across a span, not a reading at an instant.
struct ClimateSample: Equatable, Sendable {

    let start: Date
    let end: Date
    let mean: Double

    var duration: TimeInterval { end.timeIntervalSince(start) }
}
