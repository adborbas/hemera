import Foundation
import HemeraLog

/// Holds the current `Settings` and persists them. A reference type so owners share one
/// value; not `@Observable` — the UI observes the owners.
@MainActor
protocol SettingsStoring: AnyObject {
    var settings: Settings { get set }
}

/// `SettingsStoring` backed by `UserDefaults`, under a single key.
@MainActor
final class UserDefaultsSettingsStore: SettingsStoring {

    static let storageKey = "userSettings"

    /// Where an unreadable value is kept, rather than being overwritten on the next write.
    static let unreadableKey = "userSettings.unreadable"

    var settings: Settings {
        didSet {
            guard !isReadOnly else { return }
            Self.write(settings, to: defaults)
        }
    }

    private let defaults: UserDefaults

    /// Settings came from a newer build; re-encoding would drop fields we don't know about.
    private let isReadOnly: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        guard
            let json = defaults.string(forKey: Self.storageKey),
            let stored = SettingsJSON.decode(json)
        else {
            /**
             Keep anything unreadable: running on defaults means the next write would
             overwrite it, and it is the only evidence of why a user's settings reset.
            */
            if let unreadable = defaults.string(forKey: Self.storageKey) {
                defaults.set(unreadable, forKey: Self.unreadableKey)
                Log.warning("Stored settings unreadable — copied to \(Self.unreadableKey), running on defaults")
            }
            self.settings = Settings()
            self.isReadOnly = false
            return
        }

        if stored.schemaVersion > SettingsMigration.currentVersion {
            Log.warning("Settings are from a newer build — running on defaults, not saving")
            self.settings = Settings()
            self.isReadOnly = true
        } else {
            self.settings = stored
            self.isReadOnly = false
        }
    }
}

// MARK: - Writing Before a Store Exists

extension UserDefaultsSettingsStore {

    /// For `SettingsMigration`, which runs before any store is built and so must not know
    /// the key or the format.
    static func hasStoredSettings(in defaults: UserDefaults) -> Bool {
        defaults.string(forKey: storageKey) != nil
    }

    static func write(_ settings: Settings, to defaults: UserDefaults) {
        guard let json = SettingsJSON.encode(settings) else {
            Log.error("Failed to encode settings — not saved")
            return
        }
        defaults.set(json, forKey: storageKey)
    }
}

// MARK: - Format

/// How settings are stored is this file's business only.
private enum SettingsJSON {

    /// Pretty-printed and sorted, so the stored value stays legible and diffs cleanly.
    static func encode(_ settings: Settings) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard
            let data = try? encoder.encode(settings),
            let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    /**
     Overlays what is stored onto the defaults: the synthesized decoder ignores property
     defaults and throws `keyNotFound`, so a newly added setting would wipe the rest.
    */
    static func decode(_ json: String) -> Settings? {
        guard
            let data = json.data(using: .utf8),
            let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let defaultData = try? JSONEncoder().encode(Settings()),
            let defaults = try? JSONSerialization.jsonObject(with: defaultData) as? [String: Any],
            let merged = try? JSONSerialization.data(withJSONObject: merging(defaults, over: stored))
        else { return nil }

        return try? JSONDecoder().decode(Settings.self, from: merged)
    }

    /// Arrays are replaced wholesale — merging element-wise would leave phantom tail entries.
    static func merging(_ defaults: [String: Any], over stored: [String: Any]) -> [String: Any] {
        var result = defaults
        for (key, storedValue) in stored {
            if let storedChild = storedValue as? [String: Any],
               let defaultChild = result[key] as? [String: Any] {
                result[key] = merging(defaultChild, over: storedChild)
            } else {
                result[key] = storedValue
            }
        }
        return result
    }
}

#if DEBUG
extension UserDefaultsSettingsStore {

    /// Throwaway suite, so previews never touch the real settings.
    static func preview() -> UserDefaultsSettingsStore {
        UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "com.hemera.preview") ?? .standard)
    }
}
#endif
