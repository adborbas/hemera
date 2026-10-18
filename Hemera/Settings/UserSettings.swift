import Foundation
import HemeraLog

/**
 Every user setting, as one value type. Adding a setting is one line here.

 A feature owning three or more related settings gets its own nested struct; lone toggles
 stay top-level. Small bounded app-owned lists are fine as arrays — anything keyed by HA
 entities or unbounded belongs in SwiftData.
*/
struct SettingsValues: Codable, Equatable, Sendable {

    var schemaVersion = SettingsMigration.currentVersion

    // MARK: - Kiosk

    var stayAwake = false
    var dimTimeout: DimTimeout = .thirtySeconds
    var clockFormat: ClockFormat = .system

    // MARK: - Areas

    var areasGroupedByFloor = true
}

/**
 Observable holder for `SettingsValues`, persisting them on every change.

 Values are reached directly — `settings.stayAwake` — via dynamic member lookup, so the
 value type stays an implementation detail and adding a setting needs nothing here.
*/
@dynamicMemberLookup
@Observable
@MainActor
final class UserSettings {

    /// Mutating any field replaces the value, so `didSet` catches nested changes too.
    private var values: SettingsValues { didSet { save() } }

    subscript<Value>(dynamicMember keyPath: WritableKeyPath<SettingsValues, Value>) -> Value {
        get { values[keyPath: keyPath] }
        set { values[keyPath: keyPath] = newValue }
    }

    @ObservationIgnored private var store: (any SettingsStoring)?

    /// Set when the stored settings came from a newer build, so we never overwrite them.
    @ObservationIgnored private var isSaveSuppressed = false

    init(values: SettingsValues = SettingsValues()) {
        self.values = values
    }

    /// Falls back to defaults for anything missing or unreadable. Never writes: the store
    /// is attached only after decoding.
    /// Falls back to defaults for anything missing or unreadable. Never writes: the store
    /// is attached only after loading.
    static func load(from store: any SettingsStoring) -> UserSettings {
        let settings = UserSettings()

        if let loaded = store.load() {
            if loaded.schemaVersion > SettingsMigration.currentVersion {
                /**
                 Written by a newer build. Re-encoding it would drop every field this
                 build doesn't know about, so run on defaults and stay read-only.
                */
                Log.warning("SettingsValues are from a newer build — running on defaults, not saving")
                settings.isSaveSuppressed = true
            } else {
                settings.values = loaded
            }
        }

        settings.store = store
        return settings
    }

    func save() {
        guard let store, !isSaveSuppressed else { return }
        store.save(values)
    }

    func resetToDefaults() {
        values = SettingsValues()
    }
}

// MARK: - Resilient Decoding

extension SettingsValues {

    /**
     Overlays the stored object on the defaults, then retries the decode with each rejected
     field reverted, so one bad value costs only that value.

     The overlay is what makes adding a setting safe: the synthesized decoder ignores
     property defaults and throws `keyNotFound`, which would otherwise wipe every setting.
    */
    static func decode(from json: String) -> SettingsValues? {
        guard
            let data = json.data(using: .utf8),
            let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let defaultData = try? JSONEncoder().encode(SettingsValues()),
            let defaults = try? JSONSerialization.jsonObject(with: defaultData) as? [String: Any]
        else { return nil }

        var candidate = merging(defaults, over: stored)
        var revertedPaths: Set<String> = []

        while true {
            guard let data = try? JSONSerialization.data(withJSONObject: candidate) else { return nil }
            do {
                return try JSONDecoder().decode(SettingsValues.self, from: data)
            } catch let error as DecodingError {
                // Empty path = not an object; repeated path = reverting didn't help.
                guard let path = offendingPath(error), !path.isEmpty else { return nil }
                let marker = path.joined(separator: ".")
                guard !revertedPaths.contains(marker) else { return nil }
                revertedPaths.insert(marker)
                Log.warning("Settings field '\(marker)' unreadable — reverting it to its default")
                revert(path: path, in: &candidate, to: defaults)
            } catch {
                return nil
            }
        }
    }

    /**
     Overlays `stored` onto `defaults`, recursing into nested objects. Arrays are replaced
     wholesale — merging element-wise would leave phantom tail entries from the defaults.
     Internal so the recursion can be tested without a decode.
    */
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

    static func revert(path: [String], in object: inout [String: Any], to defaults: [String: Any]) {
        guard let key = path.first else { return }
        guard path.count > 1 else {
            if let fallback = defaults[key] {
                object[key] = fallback
            } else {
                object.removeValue(forKey: key)
            }
            return
        }
        guard var child = object[key] as? [String: Any] else {
            // The nested value isn't an object — replace the whole branch with its default.
            if let fallback = defaults[key] { object[key] = fallback }
            return
        }
        revert(path: Array(path.dropFirst()), in: &child, to: defaults[key] as? [String: Any] ?? [:])
        object[key] = child
    }

    /// The fully qualified path of the value a decoding error objected to.
    private static func offendingPath(_ error: DecodingError) -> [String]? {
        switch error {
        case let .keyNotFound(key, context):
            context.codingPath.map(\.stringValue) + [key.stringValue]
        case let .typeMismatch(_, context), let .valueNotFound(_, context), let .dataCorrupted(context):
            context.codingPath.map(\.stringValue)
        @unknown default:
            nil
        }
    }
}
