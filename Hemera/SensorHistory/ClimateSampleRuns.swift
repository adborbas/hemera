import Foundation

/// Splits a recorded series into the contiguous runs between recording gaps.
enum ClimateSampleRuns {

    /// A new run starts once a gap exceeds 1.5× the previous bucket's width.
    static func split(_ samples: [ClimateSample]) -> [[ClimateSample]] {
        var runs: [[ClimateSample]] = []
        var current: [ClimateSample] = []

        for sample in samples {
            guard let previous = current.last else {
                current = [sample]
                continue
            }
            let elapsed = sample.start.timeIntervalSince(previous.start)
            if elapsed > 1.5 * previous.duration {
                runs.append(current)
                current = [sample]
            } else {
                current.append(sample)
            }
        }

        if !current.isEmpty { runs.append(current) }
        return runs
    }
}
