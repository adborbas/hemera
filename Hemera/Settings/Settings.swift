import Foundation

/// Every user setting. Adding one is a single line here, with a default.
struct Settings: Codable, Equatable, Sendable {

    var schemaVersion = SettingsMigration.currentVersion

    // MARK: - Kiosk

    var stayAwake = false
    /// Keeps its pre-"screensaver" name: the property name is the stored JSON key.
    var dimTimeout: ScreensaverTimeout = .thirtySeconds
    var clockFormat: ClockFormat = .system
    var screensaverShowsTheme = true

    // MARK: - Theme

    var theme = Theme.none

    // MARK: - Areas

    var areasGroupedByFloor = true

    // MARK: - Main Navigation

    /// `nil` until the pill row is first changed, which shows the default row.
    var feedRow: [FeedID]?
    /// Built-ins already added to the row once, so one the user removed stays removed.
    var offeredBuiltInFeeds = FeedID.builtIns
}
