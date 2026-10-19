import Foundation

/// Converts `Settings` to and from stored JSON.
enum SettingsJSON {

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
