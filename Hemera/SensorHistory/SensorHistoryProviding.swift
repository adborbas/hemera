import Foundation

/// How far back a climate-history fetch reaches.
enum TimeRange: CaseIterable, Equatable, Hashable {
    case day
    case week
    case month

    /// Seconds the window looks back from the fetch time.
    var interval: TimeInterval {
        switch self {
        case .day: return 24 * 60 * 60
        case .week: return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        }
    }

    /// Home Assistant's long-term-statistics bucket granularity for the window.
    var period: String {
        switch self {
        case .day: return "5minute"
        case .week: return "hour"
        case .month: return "day"
        }
    }
}

/// Fetches recorded climate history (long-term statistics) from Home Assistant.
@MainActor
protocol SensorHistoryProviding: AnyObject {
    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample]
}
