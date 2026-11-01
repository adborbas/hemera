/**
 One-dimensional value noise: stable, bounded, continuous in its position argument.
 Pure maths, no climate meaning; the climate generator samples it at its own scales.
 */
enum ValueNoise {

    /**
     Fractional Brownian motion: octaves of value noise, each half the amplitude and twice the
     frequency. A pure function of position, so every range samples one underlying curve.
    */
    static func fbm(_ x: Double, seed: UInt64, octaves: Int) -> Double {
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
    static func valueNoise(_ x: Double, seed: UInt64) -> Double {
        let whole = x.rounded(.down)
        let fraction = x - whole
        let lower = Self.lattice(Int64(whole), seed: seed)
        let upper = Self.lattice(Int64(whole) + 1, seed: seed)
        let blend = fraction * fraction * (3 - 2 * fraction)
        return lower + (upper - lower) * blend
    }

    /// A stable value in -1..<1 for one lattice point, mixed so neighbours never correlate.
    static func lattice(_ index: Int64, seed: UInt64) -> Double {
        var hash = seed ^ UInt64(bitPattern: index &* Self.latticeStride)
        hash ^= hash >> 33
        hash = hash &* 0xff51_afd7_ed55_8ccd
        hash ^= hash >> 33
        hash = hash &* 0xc4ce_b9fe_1a85_ec53
        hash ^= hash >> 33
        return Double(hash >> 11) / Double(1 << 53) * 2 - 1
    }

    private static let persistence: Double = 0.5
    private static let latticeStride: Int64 = 0x61c8_8647
}
