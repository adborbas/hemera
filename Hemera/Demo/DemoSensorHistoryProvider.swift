import Foundation

/// Demo mode has no server; a later ticket replaces this stub with a real generator.
@MainActor
final class DemoSensorHistoryProvider: SensorHistoryProviding {
    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        throw SensorHistoryError.noRecordedHistory
    }
}
