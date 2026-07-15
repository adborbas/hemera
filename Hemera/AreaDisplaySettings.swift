import Foundation

/// App-lifetime display preferences for the Areas screen, persisted to
/// `UserDefaults`. Follows the same `@Observable` + `didSet` pattern as
/// `ScreenManager`.
@Observable
@MainActor
final class AreaDisplaySettings {

    /// Whether the Areas tab groups areas into sections by Home Assistant
    /// floor. Defaults to `true`. No in-app toggle yet — reserved for a later
    /// iteration.
    var areasGroupedByFloor: Bool {
        didSet {
            UserDefaults.standard.set(areasGroupedByFloor, forKey: Keys.areasGroupedByFloor)
        }
    }

    private enum Keys {
        static let areasGroupedByFloor = "areaDisplaySettings.areasGroupedByFloor"
    }

    init() {
        let defaults = UserDefaults.standard
        // `bool(forKey:)` returns `false` for an absent key, so read the raw
        // object first to honour the `true` default on first launch.
        if defaults.object(forKey: Keys.areasGroupedByFloor) == nil {
            self.areasGroupedByFloor = true
        } else {
            self.areasGroupedByFloor = defaults.bool(forKey: Keys.areasGroupedByFloor)
        }
    }
}
