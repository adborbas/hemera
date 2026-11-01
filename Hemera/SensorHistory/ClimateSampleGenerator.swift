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
        let profile = Profile.forEntity(entityId, isHumidity: isHumidity)
        let phase = Self.phase(from: digest)
        let bias = Self.bias(from: digest, magnitude: profile.biasMagnitude)

        return (0..<count).map { index in
            let start = starts[index]
            let end = starts[index + 1]
            let mean = Self.mean(at: start, isHumidity: isHumidity, profile: profile, phase: phase, bias: bias)
            return ClimateSample(start: start, end: end, mean: mean)
        }
    }

    // MARK: - Profiles

    /**
     What a room's readings look like. An outdoor sensor swings far harder across a day and
     drifts further across a month than a heated room does.
    */
    struct Profile {
        let base: Double
        let amplitude: Double
        let driftAmplitude: Double
        let biasMagnitude: Double

        /// Living room and garden are the two demo areas written to read like real places.
        static func forEntity(_ entityId: String, isHumidity: Bool) -> Profile {
            if entityId.contains("living_room") {
                return isHumidity ? .indoorHumidity : .indoorTemperature
            }
            if entityId.contains("garden") {
                return isHumidity ? .outdoorHumidity : .outdoorTemperature
            }
            return isHumidity ? .genericHumidity : .genericTemperature
        }

        static let indoorTemperature = Profile(base: 21.4, amplitude: 1.1, driftAmplitude: 0.7, biasMagnitude: 0.3)
        static let indoorHumidity = Profile(base: 44.0, amplitude: 5.0, driftAmplitude: 3.0, biasMagnitude: 0.8)
        static let outdoorTemperature = Profile(base: 11.5, amplitude: 6.5, driftAmplitude: 3.5, biasMagnitude: 0.6)
        static let outdoorHumidity = Profile(base: 71.0, amplitude: 13.0, driftAmplitude: 6.0, biasMagnitude: 1.0)
        static let genericTemperature = Profile(base: 20.5, amplitude: 2.8, driftAmplitude: 0.9, biasMagnitude: 0.5)
        static let genericHumidity = Profile(base: 52.5, amplitude: 11.0, driftAmplitude: 3.5, biasMagnitude: 0.8)
    }

    // MARK: - Per-sample curve

    /**
     A daily sine, rotated a quarter cycle to `cos` for humidity so one room's two measurements
     never draw the same line, plus a slow drift that keeps a month from repeating itself.
    */
    private static func mean(
        at date: Date,
        isHumidity: Bool,
        profile: Profile,
        phase: Double,
        bias: Double
    ) -> Double {
        let seconds = date.timeIntervalSince1970
        let theta = 2 * .pi * (seconds / Self.day) + phase
        let drift = profile.driftAmplitude * sin(2 * .pi * (seconds / Self.driftPeriod) + phase)
        let wave = isHumidity ? cos(theta) : sin(theta)
        return profile.base + bias + profile.amplitude * wave + drift
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
        case .month: return 60 * 60
        }
    }

    private static let day: TimeInterval = 24 * 60 * 60

    /// Not a whole number of days, so the drift never lands in step with the daily wave.
    private static let driftPeriod: TimeInterval = 5.5 * 24 * 60 * 60
    private static let fnvPrime: UInt64 = 0x0000_0100_0000_01b3      // FNV-1a-64 prime
    private static let phaseSpan: Double = 12

    // Bases and amplitudes stay inside the plausible temperature/humidity bands.
}
