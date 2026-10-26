import Foundation
@testable import Hemera

/// Records each climate-history request and returns a configurable result or error.
@MainActor
final class MockSensorHistoryProvider: SensorHistoryProviding {

    struct Request: Equatable {
        let entityId: String
        let range: TimeRange
    }

    var requests: [Request] = []
    var result: [ClimateSample]?
    var error: Error?

    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        requests.append(Request(entityId: entityId, range: range))
        if let error { throw error }
        return result ?? []
    }
}
