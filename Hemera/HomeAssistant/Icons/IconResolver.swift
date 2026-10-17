import Mortar
import Foundation

/**
 Resolves Material Design Icon names for entities using Home Assistant's own icon translations.

 Reference type on purpose: the server's translations replace the bundled snapshot once the sync
 delivers them, and `@Observable` is what lets the cards whose icon changed re-render. A value type
 would leave every card showing the snapshot until some unrelated state change.
*/
@Observable
@MainActor
final class IconResolver: IconResolving {

    // MARK: - Properties

    /**
     The app-wide resolver.

     Icon translations are Home Assistant core's own `icons.json` data, not user or server data —
     two servers on the same core version return identical payloads — so one app-lifetime instance
     is the right scope. `@MainActor` isolation makes this a safe static without `nonisolated(unsafe)`.
    */
    static let shared = IconResolver(translations: .bundled())

    private(set) var translations: IconTranslations

    // MARK: - Init

    init(translations: IconTranslations) {
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
        forDomain domain: String,
        deviceClass: String?,
        state: String?,
        entityIcon: String?
    ) -> String? {
        if let entityIcon, let overridden = MDIIconName.normalised(entityIcon) {
            return overridden
        }
        guard let entry = translations.entry(domain: domain, deviceClass: deviceClass) else { return nil }
        return Self.icon(from: entry, state: state)
    }

    /**
     Bare MDI name for a specific entity attribute, such as climate's `hvac_action`.

     Deliberately never falls back to the attribute entry's own `default`: Home Assistant ships
     `mdi:circle-medium` there, a placeholder dot that is meaningless as an entity card icon. Callers
     decide their own fallback.
    */
    func attributeIconName(
        forDomain domain: String,
        deviceClass: String?,
        attribute: String,
        value: String?
    ) -> String? {
        guard let value,
              let entry = translations.entry(domain: domain, deviceClass: deviceClass),
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
