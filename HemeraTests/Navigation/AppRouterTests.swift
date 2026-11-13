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

        router.sessionReady(succeeded: true)

        #expect(router.destination == .authenticated)
    }

    @Test func sessionReady_whenAlreadyAuthenticated_remainsAuthenticated() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)

        router.sessionReady(succeeded: true)

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

    // MARK: - Ways Into the App

    /// Onboarding's Home step needs the root until the user finishes it.
    @Test func didAuthenticate_fromOnboarding_keepsOnboardingUntilItFinishes() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)

        authManager.didAuthenticate(with: Self.testCredentials)
        #expect(router.destination == .onboarding)
        #expect(router.sessionSync == .pending)

        router.sessionReady(succeeded: true)
        #expect(router.destination == .onboarding)
        #expect(router.sessionSync == .succeeded)

        router.navigate(to: .authenticated)
        #expect(router.destination == .authenticated)
    }

    @Test func didAuthenticate_afterExpiry_connectsThenOpensTheApp() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        authManager.simulateSessionExpiry()
        let router = AppRouter(authManager: authManager)

        authManager.didAuthenticate(with: Self.testCredentials)
        #expect(router.destination == .connecting)

        router.sessionReady(succeeded: true)
        #expect(router.destination == .authenticated)
    }

    /// Demo mode enters through `AppCoordinator`, never through a login.
    @Test func demoFromOnboarding_opensTheAppAndExitReturnsToOnboarding() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)

        router.navigate(to: .authenticated)
        #expect(router.destination == .authenticated)
        router.navigate(to: .onboarding)
        authManager.didAuthenticate(with: Self.testCredentials)

        #expect(router.destination == .onboarding)
    }

    @Test func sessionExpiry_duringOnboarding_navigatesToSessionExpired() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)
        authManager.didAuthenticate(with: Self.testCredentials)

        authManager.simulateSessionExpiry()

        #expect(router.destination == .sessionExpired)
    }

    @Test func logout_fromOnboarding_staysOnOnboardingAndForgetsTheSync() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)
        authManager.didAuthenticate(with: Self.testCredentials)
        router.sessionReady(succeeded: true)

        authManager.logout()

        #expect(router.destination == .onboarding)
        #expect(router.sessionSync == .pending)
    }

    /// A new login must not inherit the previous session's finished sync.
    @Test func didAuthenticate_resetsSessionSync() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        let router = AppRouter(authManager: authManager)
        router.sessionReady(succeeded: true)
        authManager.simulateSessionExpiry()

        authManager.didAuthenticate(with: Self.testCredentials)

        #expect(router.sessionSync == .pending)
    }

    // MARK: - Sync Outcome

    /// Onboarding shows Unable to Connect for a failed sync instead of an empty Home.
    @Test func sessionReady_failed_recordsTheFailureAndStillLeavesConnecting() {
        let authManager = MockAuthManager()
        authManager.didAuthenticate(with: Self.testCredentials)
        authManager.simulateSessionExpiry()
        let router = AppRouter(authManager: authManager)
        authManager.didAuthenticate(with: Self.testCredentials)

        router.sessionReady(succeeded: false)

        #expect(router.sessionSync == .failed)
        #expect(router.destination == .authenticated)
    }

    @Test func sessionReady_succeededAfterAFailure_recordsTheSuccess() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)
        authManager.didAuthenticate(with: Self.testCredentials)
        router.sessionReady(succeeded: false)

        router.sessionReady(succeeded: true)

        #expect(router.sessionSync == .succeeded)
    }

    /// A retry must not keep showing the failure it is retrying.
    @Test func syncRetried_afterAFailure_isPendingAgain() {
        let authManager = MockAuthManager()
        let router = AppRouter(authManager: authManager)
        authManager.didAuthenticate(with: Self.testCredentials)
        router.sessionReady(succeeded: false)

        router.syncRetried()

        #expect(router.sessionSync == .pending)
    }
}
