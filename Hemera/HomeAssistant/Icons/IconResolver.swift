import Mortar
import Foundation

/**
 Resolves Material Design Icon names using Home Assistant's own icon translations.

 `@Observable` so cards re-render when the sync replaces the bundled snapshot with the server's.
*/
@Observable
@MainActor
final class IconResolver: IconResolving {

    // MARK: - Properties

    /**
     App-lifetime: translations are HA core's own `icons.json`, identical across servers on a
     given core version, so there is nothing session-scoped to keep apart.
    */
    static let shared = IconResolver(translations: .bundled())

    private(set) var translations: IconTranslations

    /// Kept so each update overlays the bundled snapshot rather than the previous server's response.
    private let baseline: IconTranslations

    // MARK: - Init

    init(translations: IconTranslations) {
        self.translations = translations
        self.baseline = translations
    }

    // MARK: - Public Methods

    func update(_ translations: IconTranslations) {
        self.translations = baseline.merging(translations)
    }

    /**
     Precedence must match the frontend's `getEntityIcon` (`src/data/icons.ts`) exactly — diverging
     means users see different icons here than on the dashboard they already know.
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
     Never falls back to the attribute's own `default` — HA ships `mdi:circle-medium` there, a
     placeholder dot. Callers pick their own fallback.
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
