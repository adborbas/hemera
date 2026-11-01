import Foundation
import Testing
@testable import Hemera

@MainActor
struct ClimateSampleGeneratorTests {

    // MARK: - Fixtures

    /// A frozen fetch time, so every generated series is asserted exactly.
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Determinism

    /// The guarantee the screenshot suite leans on: identical inputs make identical output.
    @Test
    func samples_sameInputsProduceIdenticalArray() {
        let a = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)
        let b = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)

        #expect(a == b)
    }

    // MARK: - Distinct shapes per measurement

    @Test
    func samples_humidityAndTemperatureIdsProduceDifferentSeries() {
        let temperature = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)
        let humidity = ClimateSampleGenerator.samples(entityId: "sensor.living_room_humidity", range: .day, now: Self.now)

        #expect(temperature != humidity)
    }

    /// The per-entity seed nudges each room's curve, so two rooms aren't identical.
    @Test
    func samples_distinctTemperatureIdsProduceDifferentSeries() {
        let livingRoom = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)
        let office = ClimateSampleGenerator.samples(entityId: "sensor.office_temperature", range: .day, now: Self.now)

        #expect(livingRoom != office)
    }

    // MARK: - Bucket sizing

    @Test
    func samples_dayRangeProducesFiveMinuteBuckets() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)

        #expect(samples[1].start.timeIntervalSince(samples[0].start) == 300)
    }

    @Test
    func samples_weekRangeProducesHourBuckets() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .week, now: Self.now)

        #expect(samples[1].start.timeIntervalSince(samples[0].start) == 3_600)
    }

    /// Hourly, matching what the real provider asks Home Assistant for over a month.
    @Test
    func samples_monthRangeProducesHourBuckets() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .month, now: Self.now)

        #expect(samples[1].start.timeIntervalSince(samples[0].start) == 3_600)
    }

    /**
     Daily buckets stepped exactly one period of the daily wave, so a month drew one flat line.
     The month must vary across both a day and the whole window.
    */
    @Test
    func samples_monthRangeVariesRatherThanRepeatingOneValue() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .month, now: Self.now)
        let means = samples.map(\.mean)

        let lowest = means.min() ?? 0
        let highest = means.max() ?? 0
        #expect(highest - lowest > 1)

        // Same hour a week apart must differ, or the month is just one day repeated.
        #expect(means[0] != means[24 * 7])
    }

    @Test
    func samples_gardenSwingsWiderThanTheLivingRoom() {
        let indoor = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)
        let outdoor = ClimateSampleGenerator.samples(entityId: "sensor.garden_temperature", range: .day, now: Self.now)

        let indoorSpread = (indoor.map(\.mean).max() ?? 0) - (indoor.map(\.mean).min() ?? 0)
        let outdoorSpread = (outdoor.map(\.mean).max() ?? 0) - (outdoor.map(\.mean).min() ?? 0)

        #expect(outdoorSpread > indoorSpread * 2)
    }

    // MARK: - Current reading

    /**
     The pill reads a sensor's state and the sheet reads the newest bucket. They must name one
     number, or the two disagree on screen about the same moment.
    */
    @Test
    func currentMean_matchesTheNewestBucketTheDayRangeDraws() {
        let entityId = "sensor.living_room_temperature"
        let samples = ClimateSampleGenerator.samples(entityId: entityId, range: .day, now: Self.now)

        #expect(ClimateSampleGenerator.currentMean(entityId: entityId, now: Self.now) == samples.last?.mean)
    }

    /// Buckets sit on the clock, so a reading stays put until its bucket ends.
    @Test
    func currentMean_isStableAcrossOneBucket() {
        let entityId = "sensor.living_room_temperature"
        // Aligned to both the 5-minute and the hourly grid, so the offsets stay in one bucket.
        let aligned = Date(timeIntervalSince1970: 1_699_999_200)

        let early = ClimateSampleGenerator.currentMean(entityId: entityId, now: aligned.addingTimeInterval(60))
        let later = ClimateSampleGenerator.currentMean(entityId: entityId, now: aligned.addingTimeInterval(240))

        #expect(early == later)
    }

    /// Crossing into the next bucket is the only thing that moves the reading.
    @Test
    func currentMean_movesOnceTheBucketEnds() {
        let entityId = "sensor.living_room_temperature"
        let aligned = Date(timeIntervalSince1970: 1_699_999_200)

        let inside = ClimateSampleGenerator.currentMean(entityId: entityId, now: aligned.addingTimeInterval(60))
        let next = ClimateSampleGenerator.currentMean(entityId: entityId, now: aligned.addingTimeInterval(360))

        #expect(inside != next)
    }

    // MARK: - Texture

    /**
     Every range samples one underlying curve, so an instant two ranges share must agree.
     A random walk would satisfy the determinism tests and still fail this one.
    */
    @Test
    func samples_instantSharedByTwoRanges_hasTheSameMean() {
        let day = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)
        let week = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .week, now: Self.now)

        let dayMeans = Dictionary(uniqueKeysWithValues: day.map { ($0.start, $0.mean) })
        let shared = week.compactMap { sample in dayMeans[sample.start].map { ($0, sample.mean) } }

        #expect(shared.count > 10)
        for (fromDay, fromWeek) in shared {
            #expect(abs(fromDay - fromWeek) < 0.000_001)
        }
    }

    /**
     A day apart is a whole period of the daily wave, so a pure sine would repeat exactly.
     Anything that differs is the texture that stops the chart reading as computed.
    */
    @Test
    func samples_sameHourOnConsecutiveDays_differ() {
        let week = ClimateSampleGenerator.samples(entityId: "sensor.garden_temperature", range: .week, now: Self.now)

        let spread = (0..<(24 * 5)).map { abs(week[$0].mean - week[$0 + 24].mean) }
        #expect((spread.max() ?? 0) > 0.2)
    }

    /// A room warms faster than it cools, which a plain sine cannot express.
    @Test
    func samples_dailyWaveRisesFasterThanItFalls() {
        let day = ClimateSampleGenerator.samples(entityId: "sensor.garden_temperature", range: .day, now: Self.now)
        let means = day.map(\.mean)

        let steps = zip(means, means.dropFirst()).map { $1 - $0 }
        let rising = steps.filter { $0 > 0 }
        let falling = steps.filter { $0 < 0 }.map { -$0 }

        let averageRise = rising.reduce(0, +) / Double(rising.count)
        let averageFall = falling.reduce(0, +) / Double(falling.count)
        #expect(averageRise > averageFall * 1.15)
    }

    // MARK: - Contiguity

    /// Each end equals the next start, so the gap splitter keeps the series one run.
    @Test
    func samples_areContiguousAndSplitIntoOneRun() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .week, now: Self.now)

        for index in 0..<(samples.count - 1) {
            #expect(samples[index].end == samples[index + 1].start)
        }
        #expect(ClimateSampleRuns.split(samples).count == 1)
    }

    // MARK: - Plausible values

    /// A change to the shape may not push a mean outside its plausible band.
    @Test
    func samples_meansStayInsideThePlausibleBand() {
        let temperature = ClimateSampleGenerator.samples(entityId: "sensor.kitchen_temperature", range: .day, now: Self.now)
        let humidity = ClimateSampleGenerator.samples(entityId: "sensor.bathroom_humidity", range: .day, now: Self.now)

        for sample in temperature {
            #expect(sample.mean >= 16)
            #expect(sample.mean <= 25)
        }
        for sample in humidity {
            #expect(sample.mean >= 37)
            #expect(sample.mean <= 68)
        }
    }

    // MARK: - Coverage

    @Test
    func samples_dayRangeCoversAboutTwentyFourHours() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .day, now: Self.now)

        #expect(samples.count == 288)
        let span = samples.last!.end.timeIntervalSince(samples.first!.start)
        #expect(abs(span - 86_400) < 1)
    }
}
