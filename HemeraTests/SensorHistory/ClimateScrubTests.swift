import Foundation
import Testing
@testable import Hemera

struct ClimateScrubTests {

    // MARK: - date(atPosition:)

    @Test
    func date_emptySamples_returnsNil() {
        let scrub = ClimateScrub(samples: [])

        #expect(scrub.date(atPosition: 0) == nil)
        #expect(scrub.date(atPosition: 0.5) == nil)
        #expect(scrub.date(atPosition: 1) == nil)
    }

    @Test
    func date_singleSample_mapsEveryPositionToItsStart() {
        let scrub = ClimateScrub(samples: [
            ClimateSample(start: Date(timeIntervalSince1970: 1000), end: Date(timeIntervalSince1970: 1300), mean: 20.5),
        ])

        for position in [0.0, 0.25, 0.5, 0.9, 1.0, 1.5] {
            #expect(scrub.date(atPosition: position) == Date(timeIntervalSince1970: 1000))
        }
    }

    @Test
    func date_positionsZeroAndOne_mapToFirstAndLastSampleStarts() {
        let scrub = ClimateScrub(samples: samples(20, 21, 22))

        #expect(scrub.date(atPosition: 0) == Date(timeIntervalSince1970: 1000))
        #expect(scrub.date(atPosition: 1) == Date(timeIntervalSince1970: 1600))
    }

    @Test
    func date_positionOutsideDomain_clampsToNearestSeriesEdge() {
        let scrub = ClimateScrub(samples: samples(20, 21, 22))

        #expect(scrub.date(atPosition: -1) == Date(timeIntervalSince1970: 1000))
        #expect(scrub.date(atPosition: 1.5) == Date(timeIntervalSince1970: 1600))
    }

    /**
     Unevenly spaced starts are where an index-linear and a time-linear walk disagree, so every
     curve point's date must survive a round trip through `date(atPosition:)`.
    */
    @Test
    func date_unevenlySpacedSamples_matchesTheCurvePointDates() {
        let base = Date(timeIntervalSince1970: 1000)
        let uneven = [
            ClimateSample(start: base.addingTimeInterval(0), end: base.addingTimeInterval(300), mean: 20),
            ClimateSample(start: base.addingTimeInterval(300), end: base.addingTimeInterval(600), mean: 21),
            ClimateSample(start: base.addingTimeInterval(600), end: base.addingTimeInterval(900), mean: 22),
            ClimateSample(start: base.addingTimeInterval(86_400), end: base.addingTimeInterval(86_700), mean: 23),
        ]
        let scrub = ClimateScrub(samples: uneven)

        // Positions past the gap land between the last two starts, where the two walks diverge.
        for point in ClimateCurve.points(for: uneven) {
            #expect(scrub.date(atPosition: point.position) == point.date)
        }
    }

    // MARK: - sample(atPosition:)

    @Test
    func sample_emptySamples_returnsNil() {
        let scrub = ClimateScrub(samples: [])

        #expect(scrub.sample(atPosition: 0.5) == nil)
    }

    @Test
    func sample_positionsZeroAndOne_resolveFirstAndLastSamples() {
        let scrub = ClimateScrub(samples: samples(20, 21, 22))

        #expect(scrub.sample(atPosition: 0)?.mean == 20)
        #expect(scrub.sample(atPosition: 1)?.mean == 22)
    }

    /// The interval is half-open: a bucket's own `start` resolves that bucket, not the previous.
    @Test
    func sample_positionOnSampleStart_resolvesThatSampleNotTheNext() {
        let scrub = ClimateScrub(samples: samples(20, 21, 22))

        // Starts run 1000...1600, so position 0.5 is 1300 — the middle bucket's own start.
        #expect(scrub.sample(atPosition: 0.5)?.mean == 21)
    }

    /// The interval is half-open: a bucket's `end` does not resolve that bucket, it resolves the next.
    @Test
    func sample_positionOnSampleEnd_resolvesTheNextSample() {
        let scrub = ClimateScrub(samples: samples(20, 21, 22))

        // Position 1 is 1600, the end of the [1300, 1600) bucket, so it resolves the next one.
        #expect(scrub.sample(atPosition: 1.0)?.mean == 22)
    }

    /// A date inside a recording gap resolves no sample, which is what yields a mean-less readout.
    @Test
    func sample_positionInsideRecordingGap_returnsNil() {
        let base = Date(timeIntervalSince1970: 1000)
        let gapped = [
            ClimateSample(start: base, end: base.addingTimeInterval(300), mean: 20),
            ClimateSample(start: base.addingTimeInterval(600), end: base.addingTimeInterval(900), mean: 22),
        ]
        let scrub = ClimateScrub(samples: gapped)

        // Position 0.5 is 1300, where the first bucket ends; 0.6 is 1360, strictly inside the gap.
        #expect(scrub.sample(atPosition: 0.5) == nil)
        #expect(scrub.sample(atPosition: 0.6) == nil)
    }

    // MARK: - Helpers

    private func samples(_ means: Double...) -> [ClimateSample] {
        means.enumerated().map { index, value in
            let start = Date(timeIntervalSince1970: 1000 + TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: value)
        }
    }
}
