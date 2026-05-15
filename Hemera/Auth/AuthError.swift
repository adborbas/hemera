import Foundation

enum AuthError: Error {
    case notAuthenticated
    case sessionExpired
    case stateMismatch
    case noAuthCode
    case unknownCallback
    case invalidServerURL
}
