import Mortar
import Foundation

/**
 Resolves Material Design Icon names for entities using Home Assistant's own icon translations.

 Reference type on purpose: translations arrive from the WebSocket after the first paint, so a value
 type would give SwiftUI no reason to recompute and every card would stay blank until some unrelated
 state change. `@Observable` lets the cards that gained an icon re-render and nothing else.
*/
@Observable
@MainActor
final class IconResolver {

    // MARK: - Properties

    private(set) var translations: IconTranslations?

    // MARK: - Init

    init(translations: IconTranslations? = nil) {
        self.translations = translations
    }

    // MARK: - Public Methods

    func update(_ translations: IconTranslations) {
        self.translations = translations
    }

    /**
     Bare MDI name for an entity, mirroring the precedence in Home Assistant's frontend
     (`src/data/icons.ts`, `getEntityIcon`): the entity's own `icon` attribute wins, then its
     `device_class` entry, then the domain-wide fallback, preferring a state match over the default.

     Following HA's order exactly is the point of the whole feature — diverging means users see
     different icons in Hemera than on the dashboard they already know.
    */
    func iconName(
        domain: String,
        deviceClass: String? = nil,
        state: String? = nil,
        entityIcon: String? = nil
    ) -> String? {
        if let entityIcon, let overridden = MDIIconName.normalised(entityIcon) {
            return overridden
        }
        guard let entry = translations?.entry(domain: domain, deviceClass: deviceClass) else { return nil }
        return Self.icon(from: entry, state: state)
    }

    /**
     Bare MDI name for a specific entity attribute, such as climate's `hvac_action`.

     Deliberately never falls back to the attribute entry's own `default`: Home Assistant ships
     `mdi:circle-medium` there, a placeholder dot that is meaningless as an entity card icon. Callers
     decide their own fallback.
    */
    func attributeIconName(
        domain: String,
        deviceClass: String? = nil,
        attribute: String,
        value: String?
    ) -> String? {
        guard let value,
              let entry = translations?.entry(domain: domain, deviceClass: deviceClass),
              let match = entry.stateAttributes?[attribute]?.state?[value] else { return nil }
        return MDIIconName.normalised(match)
    }

    // MARK: - Private Methods

    private static func icon(from entry: IconTranslations.Entry, state: String?) -> String? {
        if let state, let match = entry.state?[state] {
            return MDIIconName.normalised(match)
        }
        return entry.defaultIcon.flatMap(MDIIconName.normalised)
    }
}
