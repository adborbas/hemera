import Foundation

/**
 Answers "which icon does this entity use right now?" with a bare Material Design Icon name.

 The only thing call sites know about icon resolution. They ask about a domain and a state; whether
 the answer came from Home Assistant's own translations, a bundled snapshot, or something else
 entirely is the implementation's business.

 Read-only on purpose — seeding and refreshing translations belongs to whoever owns the connection,
 not to the cards doing the asking.
*/
@MainActor
protocol IconResolving {

    /// Bare MDI name for an entity, or `nil` when nothing in the translations covers it.
    func iconName(forDomain domain: String, deviceClass: String?, state: String?, entityIcon: String?) -> String?

    /// Bare MDI name for a specific entity attribute, such as climate's `hvac_action`.
    func attributeIconName(forDomain domain: String, deviceClass: String?, attribute: String, value: String?) -> String?
}

/**
 Shorthands supplying the arguments most call sites do not care about, which the requirements above
 cannot carry themselves.

 The `forDomain:` label on the requirements keeps these separate functions rather than default
 implementations of them — same signature would make a shorthand its own witness and recurse forever
 for any conformer that relied on it.
*/
extension IconResolving {

    func iconName(
        domain: String,
        deviceClass: String? = nil,
        state: String? = nil,
        entityIcon: String? = nil
    ) -> String? {
        iconName(forDomain: domain, deviceClass: deviceClass, state: state, entityIcon: entityIcon)
    }

    func attributeIconName(
        domain: String,
        deviceClass: String? = nil,
        attribute: String,
        value: String?
    ) -> String? {
        attributeIconName(forDomain: domain, deviceClass: deviceClass, attribute: attribute, value: value)
    }
}
