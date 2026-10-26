import Foundation

/**
 Demo climate history: a synthetic daily swing per sensor, so demo mode shows a
 chart instead of "no recorded history".
 */
@MainActor
final class DemoSensorHistoryProvider: SensorHistoryProviding {

    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        ClimateSampleGenerator.samples(entityId: entityId, range: range, now: Date())
    }
}
