import Foundation
@testable import Hemera

@MainActor
final class MockAuthManager: AuthManaging {
    var state: AuthState = .unauthenticated
    var credentials: ServerCredentials?

    var didAuthenticateCallCount = 0
    var logoutCallCount = 0
    var validAccessTokenResult: Result<String, Error> = .success("mock-token")

    private var onChangeHandlers: [(AuthState, AuthChangeReason) -> Void] = []

    func addOnChangeHandler(_ handler: @escaping (AuthState, AuthChangeReason) -> Void) {
        onChangeHandlers.append(handler)
    }

    func didAuthenticate(with creds: ServerCredentials) {
        didAuthenticateCallCount += 1
        credentials = creds
        state = .authenticated
        onChangeHandlers.forEach { $0(.authenticated, .userInitiated) }
    }

    func validAccessToken() async throws -> String {
        try validAccessTokenResult.get()
    }

    func logout() {
        logoutCallCount += 1
        credentials = nil
        state = .unauthenticated
        onChangeHandlers.forEach { $0(.unauthenticated, .userInitiated) }
    }

    func simulateSessionExpiry() {
        credentials = nil
        state = .unauthenticated
        onChangeHandlers.forEach { $0(.unauthenticated, .sessionExpired) }
    }
}
