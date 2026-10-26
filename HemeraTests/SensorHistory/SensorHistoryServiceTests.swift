import Foundation
import HAKit
import Testing
@testable import Hemera

/**
 Verifies the `recorder/statistics_during_period` request the service builds —
 the only thing observable without a live connection.
 */
@MainActor
struct SensorHistoryServiceTests {

    // MARK: - Request shape

    @Test
    func request_dayRange_carriesPeriodTypesEntityIdAnd24HourWindow() throws {
        let request = SensorHistoryService.request(entityId: "sensor.hallway_temperature", range: .day)
        let data = request.data

        #expect(data["period"] as? String == "5minute")
        #expect((data["types"] as? [String]) == ["mean"])
        #expect((data["statistic_ids"] as? [String]) == ["sensor.hallway_temperature"])
        #expect(data["units"] == nil)

        // `end_time` is "now"; `start_time` is the 24-hour window back from the same "now".
        let formatter = ISO8601DateFormatter()
        let startString = try #require(data["start_time"] as? String)
        let endString = try #require(data["end_time"] as? String)
        let start = try #require(formatter.date(from: startString))
        let end = try #require(formatter.date(from: endString))
        #expect((86_390 ... 86_410).contains(end.timeIntervalSince(start)))
    }
}
