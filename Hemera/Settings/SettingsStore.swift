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

    var settings: Settings {
        didSet {
            guard !isReadOnly else { return }
            guard let json = SettingsJSON.encode(settings) else {
                Log.error("Failed to encode settings — not saved")
                return
            }
            defaults.set(json, forKey: Self.storageKey)
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
            if defaults.string(forKey: Self.storageKey) != nil {
                Log.warning("Stored settings unreadable — falling back to defaults")
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

#if DEBUG
extension UserDefaultsSettingsStore {

    /// Throwaway suite, so previews never touch the real settings.
    static func preview() -> UserDefaultsSettingsStore {
        UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "com.hemera.preview") ?? .standard)
    }
}
#endif
