import Foundation

/**
 Synthetic climate history for demo mode: a smooth, per-sensor daily swing, so
 a fixed `now` always draws the same plausible chart.
 */
enum ClimateSampleGenerator {

    /// Contiguous buckets over `now - interval ... now`, each its range's period wide.
    static func samples(entityId: String, range: TimeRange, now: Date) -> [ClimateSample] {
        let step = Self.bucketWidth(for: range)
        let count = Int(range.interval / step)

        // Each end borrows the next start, so a gap split keeps the series whole.
        let starts = (0...count).map { now.addingTimeInterval(TimeInterval(-(count - $0)) * step) }
        let digest = Self.digest(entityId)
        let isHumidity = entityId.contains("humidity")
        let phase = Self.phase(from: digest)
        let bias = Self.bias(from: digest, magnitude: isHumidity ? Self.humidityBias : Self.temperatureBias)

        return (0..<count).map { index in
            let start = starts[index]
            let end = starts[index + 1]
            let mean = Self.mean(at: start, isHumidity: isHumidity, phase: phase, bias: bias)
            return ClimateSample(start: start, end: end, mean: mean)
        }
    }

    // MARK: - Per-sample curve

    /**
     A daily sine, rotated a quarter cycle to `cos` for humidity, so the two
     measurements never draw the same line for one room.
     */
    private static func mean(at date: Date, isHumidity: Bool, phase: Double, bias: Double) -> Double {
        let theta = 2 * .pi * (date.timeIntervalSince1970 / Self.day) + phase
        if isHumidity {
            return Self.humidityBase + bias + Self.humidityAmplitude * cos(theta)
        }
        return Self.temperatureBase + bias + Self.temperatureAmplitude * sin(theta)
    }

    // MARK: - Per-entity seed

    /// FNV-1a over the id's UTF-8 bytes: a stable hash, unlike `hashValue`.
    private static func digest(_ entityId: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325  // FNV-1a-64 offset basis
        for byte in entityId.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* Self.fnvPrime
        }
        return hash
    }

    // High byte of the digest: a sub-daily phase so rooms' lines aren't identical.
    private static func phase(from digest: UInt64) -> Double {
        let fraction = Double((digest >> 24) & 0xff) / 256.0
        return 2 * .pi * fraction / Self.phaseSpan
    }

    // Low byte of the digest: a small nudge of the average, centred on zero.
    private static func bias(from digest: UInt64, magnitude: Double) -> Double {
        let fraction = Double(digest & 0xff) / 256.0 - 0.5
        return fraction * 2.0 * magnitude
    }

    // MARK: - Sizing and shape

    private static func bucketWidth(for range: TimeRange) -> TimeInterval {
        switch range {
        case .day: return 5 * 60
        case .week: return 60 * 60
        case .month: return 24 * 60 * 60
        }
    }

    private static let day: TimeInterval = 24 * 60 * 60
    private static let fnvPrime: UInt64 = 0x0000_0100_0000_01b3      // FNV-1a-64 prime
    private static let phaseSpan: Double = 12

    // Bases and amplitudes stay inside the plausible temperature/humidity bands.
    private static let temperatureBase: Double = 20.5
    private static let temperatureAmplitude: Double = 2.8
    private static let temperatureBias: Double = 0.5
    private static let humidityBase: Double = 52.5
    private static let humidityAmplitude: Double = 11.0
    private static let humidityBias: Double = 0.8
}
