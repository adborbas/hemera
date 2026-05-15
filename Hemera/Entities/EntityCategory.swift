import Foundation

/// Functional grouping of Home Assistant entity domains for display purposes.
///
/// Categories follow the ordering: Lights → Covers → Climate → Controls → Sensors,
/// matching Home Assistant's area page section order.
enum EntityCategory: Int, CaseIterable, Sendable {
    case lights = 0
    case covers
    case climate
    case controls
    case sensors

    /// Maps a Home Assistant entity ID to its display category.
    ///
    /// Returns `nil` for domains that should not appear as tiles (e.g., `"sensor"`).
    static func from(entityId: String) -> EntityCategory? {
        guard let dotIndex = entityId.firstIndex(of: ".") else { return nil }
        return from(domain: entityId[entityId.startIndex..<dotIndex])
    }

    /// Localized section header title.
    var title: String {
        switch self {
        case .lights:   Localization.lights
        case .covers:   Localization.covers
        case .climate:  Localization.climate
        case .controls: Localization.controls
        case .sensors:  Localization.sensors
        }
    }
}

// MARK: - Private

private extension EntityCategory {
    static func from(domain: some StringProtocol) -> EntityCategory? {
        switch domain {
        case "light":
            .lights
        case "cover":
            .covers
        case "climate":
            .climate
        case "switch", "button", "scene", "automation":
            .controls
        case "binary_sensor":
            .sensors
        default:
            nil
        }
    }
}

// MARK: - Localization

private extension EntityCategory {
    enum Localization {
        static let lights = String(
            localized: "Lights",
            comment: "Section header for light entities in area detail view"
        )
        static let covers = String(
            localized: "Covers",
            comment: "Section header for cover entities in area detail view"
        )
        static let climate = String(
            localized: "Climate",
            comment: "Section header for climate entities in area detail view"
        )
        static let controls = String(
            localized: "Controls",
            comment: "Section header for switch, button, scene, and automation entities in area detail view"
        )
        static let sensors = String(
            localized: "Sensors",
            comment: "Section header for binary sensor entities in area detail view"
        )
    }
}
