import Foundation
import HemeraLog

/// Maps Material Design Icon (MDI) names from Home Assistant to SF Symbol names.
///
/// Home Assistant uses MDI icons (e.g. `mdi:sofa`) for areas and entities.
/// Area mappings are loaded from `AreaMdiToSymbolMap.json` and entity mappings
/// from `EntityMdiToSymbolMap.json`. Multiple MDI names can map to the same
/// SF Symbol (many-to-one).
enum MDISymbolMapper {

    /// Returns the SF Symbol name for the given area MDI icon string, or `nil` if unmapped.
    ///
    /// Accepts both `"mdi:sofa"` and `"sofa"` formats.
    static func sfSymbol(for mdiIcon: String) -> String? {
        let key = mdiIcon.hasPrefix("mdi:") ? String(mdiIcon.dropFirst(4)) : mdiIcon
        return areaMapping[key]
    }

    /// Returns the SF Symbol name for the given entity MDI icon string, or `nil` if unmapped.
    ///
    /// Accepts both `"mdi:lightbulb"` and `"lightbulb"` formats.
    static func entitySFSymbol(for mdiIcon: String) -> String? {
        let key = mdiIcon.hasPrefix("mdi:") ? String(mdiIcon.dropFirst(4)) : mdiIcon
        return entityMapping[key]
    }

    // MARK: - Private

    private static let areaMapping: [String: String] = loadMapping(from: "AreaMdiToSymbolMap")
    private static let entityMapping: [String: String] = loadMapping(from: "EntityMdiToSymbolMap")

    private static func loadMapping(from resource: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            Log.error("\(resource).json missing from bundle — icon mapping disabled for \(resource)")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([Entry].self, from: data)

            var map: [String: String] = [:]
            for entry in entries {
                for mdiName in entry.mdiNames {
                    map[mdiName] = entry.sfSymbol
                }
            }
            return map
        } catch {
            Log.error("Failed to load \(resource).json — icon mapping disabled", cause: error)
            return [:]
        }
    }
}

private struct Entry: Decodable {
    let sfSymbol: String
    let mdiNames: [String]
}
