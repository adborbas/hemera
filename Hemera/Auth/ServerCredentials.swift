import Foundation

struct ServerCredentials: Codable, Sendable {
    let serverURL: URL
    var externalURL: URL?
    var accessToken: String
    var refreshToken: String
    var tokenExpiresAt: Date
    let clientId: String
}
