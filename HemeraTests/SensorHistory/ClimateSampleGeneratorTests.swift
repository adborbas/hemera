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

    @Test
    func samples_monthRangeProducesDailyBuckets() {
        let samples = ClimateSampleGenerator.samples(entityId: "sensor.living_room_temperature", range: .month, now: Self.now)

        #expect(samples[1].start.timeIntervalSince(samples[0].start) == 86_400)
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
            #expect(sample.mean >= 17)
            #expect(sample.mean <= 24)
        }
        for sample in humidity {
            #expect(sample.mean >= 40)
            #expect(sample.mean <= 65)
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
