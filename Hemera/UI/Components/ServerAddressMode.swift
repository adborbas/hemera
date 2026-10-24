import Foundation

/**
 Which of the two address-entry jobs a screen is doing.

 Carries the data and copy that differ between them, so neither screen branches on a flag.
 `edit` holds the configured address because prefilling and the "has it actually changed?"
 rule both need it. Deliberately says nothing about *how* an address is committed — that is
 an OAuth flow in one case and a credential update in the other.
*/
enum ServerAddressMode {
    case initial
    case edit(current: URL)

    var initialText: String {
        switch self {
        case .initial: ""
        case .edit(let current): current.absoluteString
        }
    }

    var title: String {
        switch self {
        case .initial: Localization.enterManually
        case .edit: Localization.serverAddress
        }
    }

    /**
     Nil when the placeholder already says everything: onboarding only needs the address
     format, which the empty field demonstrates. Editing prefills the current address, so
     there is no placeholder to read and the constraint it carries has nowhere else to go.
    */
    var footer: String? {
        switch self {
        case .initial: nil
        case .edit: Localization.editFooter
        }
    }

    var actionTitle: String {
        switch self {
        case .initial: Localization.connect
        case .edit: Localization.save
        }
    }

    /// Anything goes when first connecting; editing requires a genuinely different address.
    func allowsSubmitting(_ text: String) -> Bool {
        guard let candidate = ServerAddress.normalised(text) else { return false }
        switch self {
        case .initial:
            return true
        case .edit(let current):
            return candidate != ServerAddress.normalised(current.absoluteString)
        }
    }
}

// MARK: - Localization

private extension ServerAddressMode {
    enum Localization {
        static let enterManually = String(localized: "Enter address manually", comment: "Navigation title when entering a Home Assistant address during onboarding")
        static let serverAddress = String(localized: "Server Address", comment: "Navigation title when changing the saved Home Assistant address")
        static let editFooter = String(
            localized: "Another address for the same Home Assistant — your local address at home, or a VPN or remote address when you're away. You'll stay signed in.",
            comment: "Help text below the server address field in settings, clarifying the address must point at the same Home Assistant the user is already signed in to"
        )
        static let connect = String(localized: "Connect", comment: "Button to connect to the server")
        static let save = String(localized: "Save", comment: "Button that validates and saves the new server address")
    }
}
