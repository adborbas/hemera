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

        /**
         Buckets sit on the clock, as Home Assistant's do, not on the moment of asking. A sliding
         grid would give a sensor's seeded state and a later-opened chart two different instants.
        */
        let anchor = Date(timeIntervalSince1970: (now.timeIntervalSince1970 / step).rounded(.down) * step)

        // Each end borrows the next start, so a gap split keeps the series whole.
        let starts = (0...count).map { anchor.addingTimeInterval(TimeInterval(-(count - $0)) * step) }
        let digest = Self.digest(entityId)
        let isHumidity = entityId.contains("humidity")
        let profile = Profile.forEntity(entityId, isHumidity: isHumidity)
        let phase = Self.phase(from: digest)
        let bias = Self.bias(from: digest, magnitude: profile.biasMagnitude)

        return (0..<count).map { index in
            let start = starts[index]
            let end = starts[index + 1]
            let mean = Self.mean(
                at: start, isHumidity: isHumidity, profile: profile, phase: phase, bias: bias, seed: digest
            )
            return ClimateSample(start: start, end: end, mean: mean)
        }
    }

    /**
     The value a sensor reads now: the newest bucket the 24-hour range draws, so a demo sensor's
     state and the chart behind it cannot disagree about the present.
    */
    static func currentMean(entityId: String, now: Date) -> Double {
        Self.samples(entityId: entityId, range: .day, now: now).last?.mean ?? 0
    }

    // MARK: - Profiles

    /**
     What a room's readings look like. An outdoor sensor swings far harder across a day and
     drifts further across a month than a heated room does.
    */
    struct Profile {
        let base: Double
        let amplitude: Double
        let weatherAmplitude: Double
        let jitterAmplitude: Double
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

        static let indoorTemperature = Profile(
            base: 21.4, amplitude: 1.1, weatherAmplitude: 0.7, jitterAmplitude: 0.12, biasMagnitude: 0.3
        )
        static let indoorHumidity = Profile(
            base: 44.0, amplitude: 5.0, weatherAmplitude: 3.0, jitterAmplitude: 0.8, biasMagnitude: 0.8
        )
        static let outdoorTemperature = Profile(
            base: 11.5, amplitude: 6.5, weatherAmplitude: 3.5, jitterAmplitude: 0.5, biasMagnitude: 0.6
        )
        static let outdoorHumidity = Profile(
            base: 71.0, amplitude: 13.0, weatherAmplitude: 6.0, jitterAmplitude: 1.6, biasMagnitude: 1.0
        )
        static let genericTemperature = Profile(
            base: 20.5, amplitude: 2.8, weatherAmplitude: 0.9, jitterAmplitude: 0.2, biasMagnitude: 0.5
        )
        static let genericHumidity = Profile(
            base: 52.5, amplitude: 11.0, weatherAmplitude: 3.5, jitterAmplitude: 1.0, biasMagnitude: 0.8
        )
    }

    // MARK: - Per-sample curve

    /**
     A skewed daily wave, rotated a quarter cycle to `cos` for humidity so one room's two
     measurements never draw the same line, over weather that wanders and a fine jitter.
    */
    private static func mean(
        at date: Date,
        isHumidity: Bool,
        profile: Profile,
        phase: Double,
        bias: Double,
        seed: UInt64
    ) -> Double {
        let seconds = date.timeIntervalSince1970
        let theta = 2 * .pi * (seconds / Self.day) + phase

        /**
         Warping the angle by its own sine skews the wave without changing its period or range:
         a room warms faster than it cools, which a plain sine cannot say.
        */
        let warped = theta + Self.diurnalSkew * sin(theta)
        let wave = isHumidity ? cos(warped) : sin(warped)

        let weather = Self.fbm(seconds / Self.weatherScale, seed: seed, octaves: Self.weatherOctaves)
        let jitter = Self.fbm(seconds / Self.jitterScale, seed: seed ^ Self.jitterSalt, octaves: Self.jitterOctaves)

        return profile.base
            + bias
            + profile.amplitude * wave
            + profile.weatherAmplitude * weather
            + profile.jitterAmplitude * jitter
    }

    // MARK: - Noise

    /**
     Fractional Brownian motion: octaves of value noise, each half the amplitude and twice the
     frequency. A pure function of position, so every range samples one underlying curve.
    */
    private static func fbm(_ x: Double, seed: UInt64, octaves: Int) -> Double {
        var total = 0.0
        var amplitude = 1.0
        var frequency = 1.0
        var normal = 0.0

        for _ in 0..<octaves {
            total += amplitude * Self.valueNoise(x * frequency, seed: seed)
            normal += amplitude
            amplitude *= Self.persistence
            frequency *= 2
        }

        return normal > 0 ? total / normal : 0
    }

    /// Smoothstepped between two lattice points, so octaves blend without a crease at each integer.
    private static func valueNoise(_ x: Double, seed: UInt64) -> Double {
        let whole = x.rounded(.down)
        let fraction = x - whole
        let lower = Self.lattice(Int64(whole), seed: seed)
        let upper = Self.lattice(Int64(whole) + 1, seed: seed)
        let blend = fraction * fraction * (3 - 2 * fraction)
        return lower + (upper - lower) * blend
    }

    /// A stable value in -1..<1 for one lattice point, mixed so neighbours never correlate.
    private static func lattice(_ index: Int64, seed: UInt64) -> Double {
        var hash = seed ^ UInt64(bitPattern: index &* Self.latticeStride)
        hash ^= hash >> 33
        hash = hash &* 0xff51_afd7_ed55_8ccd
        hash ^= hash >> 33
        hash = hash &* 0xc4ce_b9fe_1a85_ec53
        hash ^= hash >> 33
        return Double(hash >> 11) / Double(1 << 53) * 2 - 1
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

    /// How far the daily wave leans; a room warms faster than it cools.
    private static let diurnalSkew: Double = 0.45

    /// Four days at the coarsest octave, down to about two hours at the finest.
    private static let weatherScale: TimeInterval = 4 * 24 * 60 * 60
    private static let weatherOctaves = 6

    /// An hour at the coarsest octave; detail the 24-hour range shows and longer ranges average away.
    private static let jitterScale: TimeInterval = 60 * 60
    private static let jitterOctaves = 3

    private static let persistence: Double = 0.5
    private static let jitterSalt: UInt64 = 0x5bf0_3635_ca4b_1d7f
    private static let latticeStride: Int64 = 0x61c8_8647
    private static let fnvPrime: UInt64 = 0x0000_0100_0000_01b3      // FNV-1a-64 prime
    private static let phaseSpan: Double = 12

    // Bases and amplitudes stay inside the plausible temperature/humidity bands.
}
