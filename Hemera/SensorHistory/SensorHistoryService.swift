import Foundation
import HAKit

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
        let request = Self.request(entityId: entityId, range: range)
        let response = try await connection.send(request)
        return try SensorHistoryDecoding.decode(response, for: entityId)
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
