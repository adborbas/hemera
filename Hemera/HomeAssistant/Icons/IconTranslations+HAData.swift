import Foundation
import HAKit

extension IconTranslations {

    /**
     Decodes the `frontend/get_icons` response for the `entity_component` category.

     Hand-rolled rather than `Codable` because HAKit hands back `HAData`, which is not a `Decoder` —
     the same reason `HADataSyncService` walks the registry responses by hand.
    */
    init?(haData: HAData) {
        guard case let .dictionary(root) = haData,
              let resources = root["resources"] as? [String: Any] else { return nil }

        let decoded = resources.compactMapValues { domainValue -> [String: Entry]? in
            guard let classes = domainValue as? [String: Any] else { return nil }
            let entries = classes.compactMapValues(Entry.init(json:))
            return entries.isEmpty ? nil : entries
        }

        guard !decoded.isEmpty else { return nil }
        self.init(resources: decoded)
    }
}

private extension IconTranslations.Entry {

    init?(json: Any) {
        guard let dict = json as? [String: Any] else { return nil }

        let defaultIcon = dict["default"] as? String
        let state = dict["state"] as? [String: String]
        let stateAttributes = (dict["state_attributes"] as? [String: Any])
            .map { $0.compactMapValues(IconTranslations.Entry.init(json:)) }
            .flatMap { $0.isEmpty ? nil : $0 }

        // An entry carrying none of the three is noise; treating it as absent keeps lookups honest.
        guard defaultIcon != nil || state != nil || stateAttributes != nil else { return nil }

        self.init(defaultIcon: defaultIcon, state: state, stateAttributes: stateAttributes)
    }
}
