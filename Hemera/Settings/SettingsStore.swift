import Foundation
import HemeraLog

/**
 Persistence for `SettingsValues`.

 Conformances only move a JSON string around — `encoded(_:)` and `decoded(from:)` below
 handle the conversion once — so a store can move to a file, iCloud or Home Assistant
 without changing anything above it.
*/
@MainActor
protocol SettingsStoring: AnyObject {
    func load() -> SettingsValues?
    func save(_ values: SettingsValues)
    func clear()
}

extension SettingsStoring {

    /// Legible, stable JSON — key order is sorted so writes diff cleanly.
    func encoded(_ values: SettingsValues) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard
            let data = try? encoder.encode(values),
            let json = String(data: data, encoding: .utf8)
        else {
            Log.error("Failed to encode settings — not saved")
            return nil
        }
        return json
    }

    /// Recovery from an older or damaged shape lives on `SettingsValues`, not in each store.
    func decoded(from json: String) -> SettingsValues? {
        SettingsValues.decode(from: json)
    }
}

/// `SettingsStoring` backed by `UserDefaults`, under a single key.
@MainActor
final class UserDefaultsSettingsStore: SettingsStoring {

    static let storageKey = "userSettings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SettingsValues? {
        guard let json = defaults.string(forKey: Self.storageKey) else { return nil }
        return decoded(from: json)
    }

    func save(_ values: SettingsValues) {
        guard let json = encoded(values) else { return }
        defaults.set(json, forKey: Self.storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
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
