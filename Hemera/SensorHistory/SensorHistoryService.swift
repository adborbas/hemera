import Foundation
import HAKit
import HemeraLog

/**
 Fetches a window of climate history over the shared WebSocket via
 `recorder/statistics_during_period`, decoding the response into samples.
 */
@MainActor
final class SensorHistoryService: SensorHistoryProviding {

    /// Resolved via `connectionManager.connection`, matching the data-sync service.
    private var connection: HAConnection { connectionManager.connection }

    private let connectionManager: HAConnectionManager

    init(connectionManager: HAConnectionManager) {
        self.connectionManager = connectionManager
    }

    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        /**
         HAKit queues a request until the socket answers and never fails it, so asking while
         disconnected would hold the chart under a spinner with no error and no way to retry.
        */
        // shortcut: a connected server that answers nothing still waits indefinitely.
        guard connectionManager.isConnected else { throw SensorHistoryError.disconnected }

        let request = Self.request(entityId: entityId, range: range)
        let response = try await connection.send(request)
        do {
            let samples = try SensorHistoryDecoding.decode(response, for: entityId)
            Log.info("Climate history for \(entityId) over \(range.period): \(samples.count) samples")
            return samples
        } catch {
            Log.error(
                "Climate history for \(entityId) over \(range.period) unreadable — \(Self.shape(of: response))",
                cause: error
            )
            throw error
        }
    }

    /// Names what the server actually sent, so an empty chart can be told from an unexpected shape.
    private static func shape(of response: HAData) -> String {
        if case let .dictionary(dictionary) = response {
            let keys = dictionary.keys.sorted().joined(separator: ", ")
            return keys.isEmpty ? "empty dictionary" : "dictionary keys: \(keys)"
        }
        return String(describing: response).prefix(200).description
    }

    /**
     `types` pins each bucket to its single mean; the server already reports the
     sensor's display unit, so no `units` key is sent.
     */
    static func request(entityId: String, range: TimeRange) -> HARequest {
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let data: [String: Any] = [
            "start_time": formatter.string(from: now.addingTimeInterval(-range.interval)),
            "end_time": formatter.string(from: now),
            "statistic_ids": [entityId],
            "period": range.period,
            "types": ["mean"],
        ]
        return HARequest(type: .webSocket("recorder/statistics_during_period"), data: data)
    }
}
