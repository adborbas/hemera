import Foundation

/// Normalises the icon names Home Assistant hands us into bare Material Design Icon names.
public enum MDIIconName {

    private static let supportedPrefixes: Set<String> = ["mdi", "hass"]

    /**
     Material Design Icon names are lowercase alphanumerics and hyphens, nothing else.

     Enforced rather than assumed because the name reaches us from an arbitrary `icon` attribute, so
     constraining it here keeps "normalised" a real guarantee and rejects nonsense before it ever
     reaches the glyph table.
    */
    private static let allowedNameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")

    /**
     Strips Home Assistant's icon prefix, returning the bare MDI name (`"mdi:garage"` → `"garage"`).

     Returns `nil` for names from an icon pack we cannot resolve — users and custom integrations can
     set prefixes like `phu:` or `si:`, and the Material Design Icons font has no glyph for those.
     Already-bare names pass through unchanged, so applying this twice is harmless.
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
