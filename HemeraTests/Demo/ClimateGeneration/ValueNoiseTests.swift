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

    @Test
    func lattice_anyIndexAndSeed_staysWithinUnitRange() {
        for index in -10_000...10_000 {
            let value = ValueNoise.lattice(Int64(index), seed: 0x5bf0_3635_ca4b_1d7f)
            #expect(value >= -1)
            #expect(value < 1)
        }
    }

    @Test
    func valueNoise_anyPositionAndSeed_staysWithinUnitRange() {
        for x in stride(from: -25.0, through: 25.0, by: 0.007) {
            let value = ValueNoise.valueNoise(x, seed: 7)
            #expect(value >= -1)
            #expect(value <= 1)
        }
    }

    // MARK: - Determinism

    /// A pure function of position and seed: the demo leans on the same input making the same curve.
    @Test
    func fbm_sameInputAndSeed_givesIdenticalOutput() {
        for x in [-37.2, -0.001, 0.5, 12.999] {
            let a = ValueNoise.fbm(x, seed: 42, octaves: 6)
            let b = ValueNoise.fbm(x, seed: 42, octaves: 6)
            #expect(a == b)
        }
    }

    /// Re-seeding is how one demo sensor gets a curve its neighbour does not share.
    @Test
    func fbm_differentSeeds_giveDifferentOutput() {
        let a = ValueNoise.fbm(3.7, seed: 1, octaves: 6)
        let b = ValueNoise.fbm(3.7, seed: 2, octaves: 6)
        #expect(a != b)
    }

    @Test
    func lattice_sameIndexAndSeed_givesIdenticalValue() {
        #expect(ValueNoise.lattice(123, seed: 9) == ValueNoise.lattice(123, seed: 9))
    }

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
