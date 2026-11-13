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

    // MARK: - Session Expiry

    @Test func logout_userInitiated_navigatesToOnboarding() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)

        authManager.logout()

        #expect(router.destination == .onboarding)
    }

    /// An expiry must never land on the welcome screen, which reads as "your setup is gone".
    @Test func sessionExpiry_navigatesToSessionExpired() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)

        authManager.simulateSessionExpiry()

        #expect(router.destination == .sessionExpired)
    }

    @Test func init_whenSessionExpired_destinationIsSessionExpired() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        authManager.simulateSessionExpiry()

        let router = AppRouter(authManager: authManager)

        #expect(router.destination == .sessionExpired)
    }

    @Test func didAuthenticate_afterExpiry_navigatesToConnecting() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)
        authManager.simulateSessionExpiry()

        authManager.didAuthenticate(with: Self.testCredentials)

        #expect(router.destination == .connecting)
    }

    @Test func logout_afterExpiry_navigatesToOnboarding() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)
        authManager.simulateSessionExpiry()

        authManager.logout()

        #expect(router.destination == .onboarding)
    }
}
