import Foundation
import HemeraLog

/// Steps the stored settings forward to the current schema. Every step must no-op when
/// its source data is absent.
enum SettingsMigration {

    static let currentVersion = 1

    /// Runs before the store is built.
    static func run(defaults: UserDefaults) {
        importLegacyKeys(from: defaults)
    }
}

// MARK: - v0 → v1: one key per setting, to a single stored value

private extension SettingsMigration {

    enum LegacyKey {
        static let stayAwake = "screenManager.stayAwake"
        static let dimTimeout = "screenManager.dimTimeout"
        static let clockFormat = "screenManager.clockFormat"
        static let areasGroupedByFloor = "areaDisplaySettings.areasGroupedByFloor"

        static let all = [stayAwake, dimTimeout, clockFormat, areasGroupedByFloor]
    }

    /// Gated per key on presence: `bool(forKey:)` returns `false` for an absent key while
    /// `areasGroupedByFloor` defaults to `true`.
    static func importLegacyKeys(from defaults: UserDefaults) {
        let present = LegacyKey.all.filter { defaults.object(forKey: $0) != nil }
        guard !present.isEmpty else { return }

        defer { present.forEach(defaults.removeObject(forKey:)) }

        // Already imported — just drop the stale keys.
        guard !UserDefaultsSettingsStore.hasStoredSettings(in: defaults) else { return }

        var settings = Settings()
        if defaults.object(forKey: LegacyKey.stayAwake) != nil {
            settings.stayAwake = defaults.bool(forKey: LegacyKey.stayAwake)
        }
        if defaults.object(forKey: LegacyKey.dimTimeout) != nil {
            settings.dimTimeout = DimTimeout(rawValue: defaults.integer(forKey: LegacyKey.dimTimeout)) ?? settings.dimTimeout
        }
        if defaults.object(forKey: LegacyKey.clockFormat) != nil {
            settings.clockFormat = ClockFormat(rawValue: defaults.integer(forKey: LegacyKey.clockFormat)) ?? settings.clockFormat
        }
        if defaults.object(forKey: LegacyKey.areasGroupedByFloor) != nil {
            settings.areasGroupedByFloor = defaults.bool(forKey: LegacyKey.areasGroupedByFloor)
        }

        UserDefaultsSettingsStore.write(settings, to: defaults)
        Log.info("Imported \(present.count) legacy settings key(s)")
    }
}
