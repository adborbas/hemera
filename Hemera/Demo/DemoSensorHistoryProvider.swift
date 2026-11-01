import Foundation

/**
 Demo climate history: a synthetic daily swing per sensor, so demo mode shows a
 chart instead of "no recorded history".
 */
@MainActor
final class DemoSensorHistoryProvider: SensorHistoryProviding {

    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        let samples = ClimateSampleGenerator.samples(entityId: entityId, range: range, now: Date())
        guard !entityId.contains("humidity") else { return samples }
        return samples.map {
            ClimateSample(start: $0.start, end: $0.end, mean: DemoTemperature.converted($0.mean))
        }
    }
}
