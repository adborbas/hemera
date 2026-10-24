import Foundation

enum AuthError: Error {
    case notAuthenticated
    case sessionExpired
    case stateMismatch
    case noAuthCode
    case unknownCallback
    case invalidServerURL
    /// The candidate address answered, but did not recognise this session's refresh token.
    case differentServer
    /// The candidate address could not be reached at all.
    case serverUnreachable
    /// The address answered, but not as a Home Assistant.
    case notHomeAssistant
}
