import Foundation

/// Errors decoding a `recorder/statistics_during_period` response.
enum SensorHistoryError: Error {
    /// The statistic id is absent from the response — distinct from a present but empty series.
    case noRecordedHistory
}

/// Reads one statistic's long-term-statistics row out of a `recorder/statistics_during_period` response.
enum SensorHistoryDecoding {

    /// Samples for `statisticId`, ascending by `start`. Throws `noRecordedHistory` if absent.
    static func decode(
        _ data: Data,
        for statisticId: String
    ) throws -> [ClimateSample] {
        let series = try JSONDecoder().decode([String: [Bucket]].self, from: data)

        // A missing key means no statistics; an empty array means a sensor reporting nothing.
        guard let buckets = series[statisticId] else {
            throw SensorHistoryError.noRecordedHistory
        }

        // A bucket HA did not aggregate carries no mean; drop it and keep its neighbours.
        return buckets
            .compactMap { bucket -> ClimateSample? in
                guard let mean = bucket.mean else { return nil }
                return ClimateSample(
                    start: Date(timeIntervalSince1970: Double(bucket.start) / 1000.0),
                    end: Date(timeIntervalSince1970: Double(bucket.end) / 1000.0),
                    mean: mean
                )
            }
            .sorted { $0.start < $1.start }
    }

    // MARK: - Payload

    private struct Bucket: Decodable, Sendable {
        let start: Int64
        let end: Int64
        let mean: Double?
    }
}
