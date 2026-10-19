import Foundation

/**
 Every user setting. Adding one is a single line here, with a default.

 A feature owning three or more related settings gets its own nested struct; lone toggles
 stay top-level. Small bounded app-owned lists are fine as arrays — anything keyed by Home
 Assistant entities or unbounded in size belongs in SwiftData.

 Each setting has exactly one owner — a view model or manager that exposes it to the UI.
 Two owners holding their own observable copies would diverge.
*/
struct Settings: Codable, Equatable, Sendable {

    var schemaVersion = SettingsMigration.currentVersion

    // MARK: - Kiosk

    var stayAwake = false
    var dimTimeout: DimTimeout = .thirtySeconds
    var clockFormat: ClockFormat = .system

    // MARK: - Areas

    var areasGroupedByFloor = true
}
