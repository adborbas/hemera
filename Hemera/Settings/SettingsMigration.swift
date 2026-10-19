import Foundation
import HemeraLog

/**
 Steps the stored settings forward to the current schema.

 Adding a field needs no migration — `SettingsJSON` overlays what is stored on the
 defaults. Migrations are for what that can't do: a semantic change to an existing field,
 and retiring compatibility code once the version proves nobody is on the old shape.

 Every step must be a no-op when its source data is absent.
*/
enum SettingsMigration {

    static let currentVersion = 1

    /// Runs before the store is built, so the import is in place when it loads.
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

    /**
     Moves the pre-`Settings` keys into the stored settings, then removes them.

     Gated per key on presence: `bool(forKey:)` returns `false` for an absent key while
     `areasGroupedByFloor` defaults to `true`, so an unconditional import would quietly
     change settings for everyone who never touched them.
    */
    static func importLegacyKeys(from defaults: UserDefaults) {
        let present = LegacyKey.all.filter { defaults.object(forKey: $0) != nil }
        guard !present.isEmpty else { return }

        defer { present.forEach(defaults.removeObject(forKey:)) }

        // Settings already exist, so the import ran before — just drop the stale keys.
        guard defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == nil else { return }

        // Starting from the defaults means an absent key keeps its default, never `false`/`0`.
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

        guard let json = SettingsJSON.encode(settings) else {
            Log.error("Failed to encode imported settings — they will fall back to defaults")
            return
        }

        defaults.set(json, forKey: UserDefaultsSettingsStore.storageKey)
        Log.info("Imported \(present.count) legacy settings key(s)")
    }
}
