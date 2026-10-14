import Foundation

struct ServerCredentials: Codable, Sendable {
    /**
     The address Hemera talks to. Mutable so the user can re-point Hemera at the
     same instance via a different address (LAN, VPN, reverse proxy) without
     re-authenticating.
    */
    var serverURL: URL
    var externalURL: URL?
    var accessToken: String
    var refreshToken: String
    var tokenExpiresAt: Date
    /**
     Pinned to the URL this was first authenticated against — never re-derive it
     from `serverURL`. HA compares `client_id` against the value stored when the
     refresh token was issued, not against the request's host, so a re-derived
     `client_id` fails refresh with `invalid_request` even though the host is fine.
    */
    let clientId: String
}
