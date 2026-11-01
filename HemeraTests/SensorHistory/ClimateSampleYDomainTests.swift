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
    func domain_withIdenticalValues_stillHasHeight() {
        let domain = ClimateSampleYDomain.domain(forValues: [21, 21, 21])

        #expect(domain.upperBound > domain.lowerBound)
        #expect(domain.contains(21))
    }

}
