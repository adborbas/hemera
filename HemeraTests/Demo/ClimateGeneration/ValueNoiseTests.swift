import Testing
@testable import Hemera

struct ValueNoiseTests {

    // MARK: - Range

    /**
     Lattice values sit in -1..<1 and value noise is a convex blend of two of them, so any
     number of octaves cannot push `fbm` outside the unit range either.
    */
    @Test
    func fbm_anyPositionAndSeed_staysWithinUnitRange() {
        for seed in 0..<50 {
            for x in stride(from: -50.0, through: 50.0, by: 0.01) {
                let value = ValueNoise.fbm(x, seed: UInt64(seed), octaves: 6)
                #expect(value >= -1)
                #expect(value <= 1)
            }
        }
    }

    // MARK: - Determinism

    // MARK: - Continuity

    /**
     The smoothstep blend kills the crease at each integer, so two points either side of a
     lattice boundary stay close together instead of jumping across the full range.
    */
    @Test
    func valueNoise_pointsEitherSideOfLatticeBoundary_differOnlySlightly() {
        for index in 0..<200 {
            let left = ValueNoise.valueNoise(Double(index) - 0.001, seed: 7)
            let right = ValueNoise.valueNoise(Double(index) + 0.001, seed: 7)
            #expect(abs(left - right) < 0.1)
        }
    }
}
