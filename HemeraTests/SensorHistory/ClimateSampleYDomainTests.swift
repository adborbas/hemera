import Foundation
import Testing

@testable import Hemera

struct ClimateSampleYDomainTests {

    @Test
    func domain_withSmallSpread_doesNotFlattenTheCurve() {
        let domain = ClimateSampleYDomain.domain(forValues: [19.8, 20.1, 20.4])

        #expect(abs((domain.upperBound - domain.lowerBound) - 0.84) < 0.0001)
    }

    @Test
    func domain_withLargeSpread_padsProportionallyNotByAConstant() {
        let domain = ClimateSampleYDomain.domain(forValues: [5, 25])

        #expect(abs((domain.upperBound - domain.lowerBound) - 28) < 0.0001)
        #expect(abs(domain.lowerBound - 1) < 0.0001)
        #expect(abs(domain.upperBound - 29) < 0.0001)
    }

    @Test
    func domain_withAnySpread_containsEverySampleMean() {
        let means: [Double] = [19.8, 20.1, 20.4]
        let domain = ClimateSampleYDomain.domain(forValues: means)

        #expect(means.allSatisfy(domain.contains))
    }

    @Test
    func domain_withIdenticalValues_stillHasHeight() {
        let domain = ClimateSampleYDomain.domain(forValues: [21, 21, 21])

        #expect(domain.upperBound > domain.lowerBound)
        #expect(domain.contains(21))
    }

    @Test
    func domain_withNoSamples_returnsAUsableRange() {
        let domain = ClimateSampleYDomain.domain(forValues: [])

        #expect(domain.lowerBound < domain.upperBound)
    }

    @Test
    func domain_fromResampledValues_ignoresASpikeNoPointLandsOn() {
        // 200 bucket means, one spike: 199i/89 never lands on index 52, so no plotted point reaches 100.
        var means = Array(repeating: 20.0, count: 200)
        means[52] = 100
        let drawnValues = ClimateCurve.runs(for: samples(means)).flatMap { $0 }.map(\.value)

        let drawnDomain = ClimateSampleYDomain.domain(forValues: drawnValues)
        let rawDomain = ClimateSampleYDomain.domain(forValues: means)

        #expect(drawnDomain.upperBound - drawnDomain.lowerBound < rawDomain.upperBound - rawDomain.lowerBound)
        #expect(drawnDomain.upperBound < 100)
    }

    // MARK: - Helpers

    private func samples(_ means: [Double]) -> [ClimateSample] {
        means.enumerated().map { index, mean in
            let start = Date(timeIntervalSince1970: Double(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: mean)
        }
    }
}
