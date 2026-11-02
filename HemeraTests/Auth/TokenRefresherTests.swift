import Foundation
import Synchronization
import Testing
@testable import Hemera

/**
 The refresh path runs every half hour for every signed-in user and decides whether they stay
 signed in, so the expiry buffer, the coalescing and the expiry propagation are all pinned here.
*/
@MainActor
struct TokenRefresherTests {

    // MARK: - Expiry buffer

    /// A token within 60 seconds of expiry is still valid, but too close to hand to a caller.
    @Test(arguments: [(600.0, "old-access", 0), (30.0, "new-access", 1), (-600.0, "new-access", 1)])
    func validToken_byTimeLeft(secondsLeft: TimeInterval, expected: String, refreshes: Int) async throws {
        let spy = RefreshSpy()

        let (token, _) = try await makeRefresher(spy).validToken(for: credentials(expiringIn: secondsLeft))

        #expect(token == expected)
        #expect(spy.callCount == refreshes)
    }

    // MARK: - Coalescing

    /// Two screens asking at once must cost the server one refresh, not one each.
    @Test
    func validToken_withTwoConcurrentCallers_refreshesOnlyOnce() async throws {
        let spy = RefreshSpy(delay: .milliseconds(100))
        let refresher = makeRefresher(spy)
        let expired = credentials(expiringIn: -600)

        async let first = refresher.validToken(for: expired)
        async let second = refresher.validToken(for: expired)
        let (one, two) = try await (first, second)

        #expect(spy.callCount == 1)
        #expect(one.0 == "new-access")
        #expect(two.0 == "new-access")
    }

    // MARK: - Persistence

    @Test
    func validToken_afterRefreshing_persistsTheNewCredentials() async throws {
        let store = MockKeychainStore()
        let refresher = makeRefresher(store: store)

        _ = try await refresher.validToken(for: credentials(expiringIn: -600))

        #expect(store.savedCredentials?.accessToken == "new-access")
    }

    /// A Keychain that refuses the write must not cost the caller the token it just obtained.
    @Test
    func validToken_whenTheKeychainWriteFails_stillReturnsTheNewToken() async throws {
        let store = MockKeychainStore(saveError: MockKeychainError())
        let refresher = makeRefresher(store: store)

        let (token, _) = try await refresher.validToken(for: credentials(expiringIn: -600))

        #expect(token == "new-access")
    }

    // MARK: - Failure

    /**
     `sessionExpired` must reach the caller so `AuthManager` tears the session down. Swallowing
     it would leave the app retrying a refresh token the server has already rejected.
    */
    @Test
    func validToken_whenTheServerRejectsTheToken_propagatesSessionExpired() async {
        let refresher = TokenRefresher(
            keychainStore: MockKeychainStore(),
            refreshToken: { _, _, _ in throw AuthError.sessionExpired }
        )

        await #expect(throws: AuthError.sessionExpired) {
            _ = try await refresher.validToken(for: credentials(expiringIn: -600))
        }
    }

    /// The in-flight task must be cleared on failure, or one network blip would wedge refreshing.
    @Test
    func validToken_afterAFailedRefresh_refreshesAgainOnTheNextCall() async throws {
        let spy = RefreshSpy(failFirstCall: true)
        let refresher = makeRefresher(spy)
        let expired = credentials(expiringIn: -600)

        await #expect(throws: (any Error).self) {
            _ = try await refresher.validToken(for: expired)
        }
        let (token, _) = try await refresher.validToken(for: expired)

        #expect(token == "new-access")
        #expect(spy.callCount == 2)
    }

    // MARK: - Helpers

    private func makeRefresher(
        _ spy: RefreshSpy = RefreshSpy(),
        store: MockKeychainStore = MockKeychainStore()
    ) -> TokenRefresher {
        TokenRefresher(keychainStore: store, refreshToken: spy.refresh)
    }

    private func credentials(expiringIn seconds: TimeInterval) -> ServerCredentials {
        ServerCredentials(
            serverURL: URL(string: "https://ha.example.com:8123")!,
            accessToken: "old-access",
            refreshToken: "refresh-token",
            tokenExpiresAt: Date().addingTimeInterval(seconds),
            clientId: "https://ha.example.com:8123"
        )
    }
}

// MARK: - Spy

private struct RefreshFailure: Error {}

/// Counts refreshes and can stall or fail one, so coalescing and recovery are observable.
private final class RefreshSpy: @unchecked Sendable {

    private let state = Mutex(0)
    private let delay: Duration?
    private let failFirstCall: Bool

    init(delay: Duration? = nil, failFirstCall: Bool = false) {
        self.delay = delay
        self.failFirstCall = failFirstCall
    }

    var callCount: Int { state.withLock { $0 } }

    var refresh: @Sendable (String, String, URL) async throws -> TokenResponse {
        { [self] _, _, _ in
            let call = state.withLock { count -> Int in
                count += 1
                return count
            }
            if let delay { try await Task.sleep(for: delay) }
            if failFirstCall, call == 1 { throw RefreshFailure() }
            return TokenResponse(
                access_token: "new-access",
                refresh_token: nil,
                expires_in: 1800,
                token_type: "Bearer"
            )
        }
    }
}
