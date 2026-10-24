import Foundation

enum ServerAddress {

    /**
     Turns typed input into a server URL, or nil if it can't be one.

     Bare hosts default to `http` because LAN and VPN addresses are usually typed without a
     scheme. Shared by onboarding and settings so the two never disagree about what counts
     as a valid address.
    */
    static func normalised(_ input: String) -> URL? {
        guard let trimmed = trimmed(input) else { return nil }
        return url(trimmed.contains("://") ? trimmed : "http://\(trimmed)")
    }

    /**
     The addresses worth trying for what was typed, best first.

     A typed scheme is honoured exactly and is never substituted, not even if the server
     redirects elsewhere: it is an instruction, not a hint, and the field stays the single
     source of truth for where we connect. A bare host names no scheme, so rather than asking
     which was meant, both are offered for the caller to resolve — https first, since an
     address that serves both should be reached over the encrypted one.

     Trying https first is also why redirects need no special handling here: an http address
     that redirects to https can only be reached after https itself failed.
    */
    static func candidates(_ input: String) -> [URL] {
        guard let trimmed = trimmed(input) else { return [] }
        guard !trimmed.contains("://") else {
            return [url(trimmed)].compactMap { $0 }
        }
        return ["https", "http"].compactMap { url("\($0)://\(trimmed)") }
    }

    // MARK: - Private

    private static func trimmed(_ input: String) -> String? {
        let trimmed = input
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func url(_ string: String) -> URL? {
        guard let components = URLComponents(string: string),
              let host = components.host, !host.isEmpty,
              let scheme = components.scheme, ["http", "https"].contains(scheme.lowercased()),
              let url = components.url else {
            return nil
        }
        return url
    }
}
