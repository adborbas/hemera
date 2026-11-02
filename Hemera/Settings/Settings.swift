import Foundation

/// Every user setting. Adding one is a single line here, with a default.
struct Settings: Codable, Equatable, Sendable {

    var schemaVersion = SettingsMigration.currentVersion

    // MARK: - Kiosk

    var stayAwake = false
    var dimTimeout: DimTimeout = .thirtySeconds
    var clockFormat: ClockFormat = .system

    // MARK: - Areas

    var areasGroupedByFloor = true

    // MARK: - Main Navigation

    /// `nil` until the pill row is first changed, which shows the default row.
    var feedRow: [FeedID]?
    /// Built-ins already added to the row once, so one the user removed stays removed.
    var offeredBuiltInFeeds = FeedID.builtIns
}
