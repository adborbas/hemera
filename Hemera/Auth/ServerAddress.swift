import Foundation

enum ServerAddress {

    /**
     Turns typed input into a server URL, or nil if it can't be one.

     Bare hosts default to `http` because LAN and VPN addresses are usually typed without a
     scheme. Shared by onboarding and settings so the two never disagree about what counts
     as a valid address.
    */
    static func normalised(_ input: String) -> URL? {
        let trimmed = input
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }

        let urlString = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: urlString),
              let host = components.host, !host.isEmpty,
              let scheme = components.scheme, ["http", "https"].contains(scheme.lowercased()),
              let url = components.url else {
            return nil
        }
        return url
    }
}
