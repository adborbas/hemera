import Foundation

/**
 Answers "which icon does this entity use right now?" with a bare Material Design Icon name.

 Read-only: seeding and refreshing translations belong to whoever owns the connection.
*/
@MainActor
protocol IconResolving {

    func iconName(forDomain domain: String, deviceClass: String?, state: String?, entityIcon: String?) -> String?

    func attributeIconName(forDomain domain: String, deviceClass: String?, attribute: String, value: String?) -> String?
}

/**
 Shorthands carrying the defaults the requirements cannot. The `forDomain:` label keeps these
 distinct — a matching signature would make a shorthand its own witness and recurse.
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
