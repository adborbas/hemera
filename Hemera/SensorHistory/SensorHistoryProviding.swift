import Foundation

/// How far back a climate-history fetch reaches.
enum TimeRange: Equatable {
    case day

    /// Seconds the window looks back from the fetch time.
    var interval: TimeInterval {
        switch self {
        case .day: return 24 * 60 * 60
        }
    }

    /// Home Assistant's long-term-statistics bucket granularity for the window.
    var period: String {
        switch self {
        case .day: return "5minute"
        }
    }
}

/// Fetches recorded climate history (long-term statistics) from Home Assistant.
@MainActor
protocol SensorHistoryProviding: AnyObject {
    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample]
}
