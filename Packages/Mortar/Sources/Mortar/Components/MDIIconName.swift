import Foundation

/// Normalises the icon names Home Assistant hands us into bare Material Design Icon names.
public enum MDIIconName {

    private static let supportedPrefixes: Set<String> = ["mdi", "hass"]

    /// Enforced, not assumed: the name arrives from an arbitrary `icon` attribute.
    private static let allowedNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")

    /**
     Strips Home Assistant's icon prefix (`"mdi:garage"` → `"garage"`), or `nil` for a pack we
     cannot draw, like the `phu:` a custom integration may set. Idempotent.
    */
    public static func normalised(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        guard let separator = trimmed.firstIndex(of: ":") else { return validated(trimmed) }

        let prefix = trimmed[trimmed.startIndex..<separator].lowercased()
        guard supportedPrefixes.contains(prefix) else { return nil }

        return validated(String(trimmed[trimmed.index(after: separator)...]))
    }

    private static func validated(_ name: String) -> String? {
        guard !name.isEmpty,
              name.unicodeScalars.allSatisfy(allowedNameCharacters.contains) else { return nil }
        return name
    }
}
