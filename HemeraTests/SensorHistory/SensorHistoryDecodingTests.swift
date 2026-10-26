import Foundation
import HAKit
import Testing
@testable import Hemera

struct SensorHistoryDecodingTests {

    // MARK: - Fixtures

    /// Two contiguous buckets — the shape `recorder/statistics_during_period` actually returns.
    private static let twoRowPayload = """
    {
      "sensor.hallway_temperature": [
        { "start": 1761500000000, "end": 1761500300000, "mean": 21.4 },
        { "start": 1761500300000, "end": 1761500600000, "mean": 21.6 }
      ]
    }
    """

    /// The same buckets, deliberately out of chronological order.
    private static let outOfOrderPayload = """
    {
      "sensor.hallway_temperature": [
        { "start": 1761500600000, "end": 1761500900000, "mean": 23.0 },
        { "start": 1761500000000, "end": 1761500300000, "mean": 21.0 },
        { "start": 1761500300000, "end": 1761500600000, "mean": 22.0 }
      ]
    }
    """

    /// Only another statistic is present; the one we ask for is absent.
    private static let absentStatisticPayload = """
    {
      "sensor.livingroom_temperature": [
        { "start": 1761500000000, "end": 1761500300000, "mean": 20.0 }
      ]
    }
    """

    /// A statistic that is present but carries no buckets — distinct from absence.
    private static let emptySeriesPayload = """
    {
      "sensor.hallway_humidity": []
    }
    """

    /// A mix: a mean present, one row with no `mean` key, and one with an explicit `null`.
    private static let mixedMeansPayload = """
    {
      "sensor.hallway_temperature": [
        { "start": 1761500000000, "end": 1761500300000, "mean": 21.0 },
        { "start": 1761500300000, "end": 1761500600000 },
        { "start": 1761500600000, "end": 1761500900000, "mean": null },
        { "start": 1761500900000, "end": 1761501200000, "mean": 23.0 }
      ]
    }
    """

    private static func data(from json: String) -> Data {
        json.data(using: .utf8) ?? Data()
    }

    // MARK: - Decoding

    @Test
    func decode_twoAscendingRows_returnsSamplesWithDatesFromMillisecondEpochs() throws {
        let samples = try SensorHistoryDecoding.decode(Self.data(from: Self.twoRowPayload), for: "sensor.hallway_temperature")

        #expect(samples.count == 2)

        // Epochs are integer milliseconds, so the decoded `Date` is `millis / 1000` seconds.
        let firstStart = Date(timeIntervalSince1970: 1_761_500_000_000 / 1000.0)
        let firstEnd = Date(timeIntervalSince1970: 1_761_500_300_000 / 1000.0)
        #expect(samples[0].start == firstStart)
        #expect(samples[0].end == firstEnd)
        #expect(samples[0].mean == 21.4)

        #expect(samples[1].start == firstEnd)
        #expect(samples[1].end == Date(timeIntervalSince1970: 1_761_500_600_000 / 1000.0))
        #expect(samples[1].mean == 21.6)
    }

    @Test
    func decode_rowsOutOfOrder_areSortedAscendingByStart() throws {
        let samples = try SensorHistoryDecoding.decode(Self.data(from: Self.outOfOrderPayload), for: "sensor.hallway_temperature")

        #expect(samples.map(\.mean) == [21.0, 22.0, 23.0])
    }

    @Test
    func decode_absentStatisticId_throwsNoRecordedHistory() {
        #expect(throws: SensorHistoryError.noRecordedHistory) {
            try SensorHistoryDecoding.decode(Self.data(from: Self.absentStatisticPayload), for: "sensor.hallway_temperature")
        }
    }

    @Test
    func decode_statisticPresentButEmpty_returnsEmptyArrayWithoutThrowing() throws {
        // Present-but-empty is a real series: it returns `[]` rather than throwing.
        let samples = try SensorHistoryDecoding.decode(Self.data(from: Self.emptySeriesPayload), for: "sensor.hallway_humidity")

        #expect(samples.isEmpty)
    }

    @Test
    func decode_rowsWithNullOrMissingMean_areSkippedWhileSiblingsSurvive() throws {
        let samples = try SensorHistoryDecoding.decode(Self.data(from: Self.mixedMeansPayload), for: "sensor.hallway_temperature")

        // The key-less row and the `null` row carry no sample; the other two survive.
        #expect(samples.count == 2)
        #expect(samples.map(\.mean) == [21.0, 23.0])
        #expect(samples.map(\.start) == [
            Date(timeIntervalSince1970: 1_761_500_000_000 / 1000.0),
            Date(timeIntervalSince1970: 1_761_500_900_000 / 1000.0),
        ])
    }

    @Test
    func sampleDuration_matchesEndMinusStart() throws {
        let samples = try SensorHistoryDecoding.decode(Self.data(from: Self.twoRowPayload), for: "sensor.hallway_temperature")
        let sample = try #require(samples.first)

        #expect(sample.duration == sample.end.timeIntervalSince(sample.start))
        #expect(sample.duration == 300.0)
    }

    @Test
    func decode_haDataDictionary_matchesDataOverload() throws {
        let object = try JSONSerialization.jsonObject(with: Self.data(from: Self.twoRowPayload))
        let fromHAData = try SensorHistoryDecoding.decode(HAData(value: object), for: "sensor.hallway_temperature")
        let fromData = try SensorHistoryDecoding.decode(Self.data(from: Self.twoRowPayload), for: "sensor.hallway_temperature")

        #expect(fromHAData == fromData)
    }
}
