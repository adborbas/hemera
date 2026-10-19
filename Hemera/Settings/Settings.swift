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
}
