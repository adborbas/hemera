import Foundation
import Testing
@testable import Hemera

@MainActor
struct AppRouterTests {

    private static var testCredentials: ServerCredentials {
        ServerCredentials(
            serverURL: URL(string: "https://ha.example.com:8123")!,
            accessToken: "test-token",
            refreshToken: "test-refresh",
            tokenExpiresAt: .distantFuture,
            clientId: "test-client"
        )
    }

    // MARK: - Initial Destination

    @Test func init_whenUnauthenticated_destinationIsOnboarding() {
        let router = AppRouter(authManager: MockAuthManager())

        #expect(router.destination == .onboarding)
    }

    @Test func init_whenAuthenticated_destinationIsAuthenticated() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)

        let router = AppRouter(authManager: authManager)

        #expect(router.destination == .authenticated)
    }

    // MARK: - sessionReady

    @Test func sessionReady_whenConnecting_navigatesToAuthenticated() {
        let router = AppRouter(authManager: MockAuthManager())
        router.navigate(to: .connecting)

        router.sessionReady()

        #expect(router.destination == .authenticated)
    }

    @Test func sessionReady_whenAlreadyAuthenticated_remainsAuthenticated() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)

        router.sessionReady()

        #expect(router.destination == .authenticated)
    }

    // MARK: - Session Expired Message

    @Test func logout_userInitiated_doesNotSetSessionExpiredMessage() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)

        authManager.logout()

        #expect(router.destination == .onboarding)
        #expect(router.sessionExpiredMessage == nil)
    }

    @Test func logout_sessionExpired_setsSessionExpiredMessage() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)

        authManager.simulateSessionExpiry()

        #expect(router.destination == .onboarding)
        #expect(router.sessionExpiredMessage != nil)
    }
}
