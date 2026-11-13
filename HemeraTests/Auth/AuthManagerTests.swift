import Foundation
import Testing
@testable import Hemera

@MainActor
@Suite(.serialized)
struct AuthManagerTests {

    private static let suiteName = "com.hemera.tests.authmanager"
    private let userDefaults: UserDefaults

    init() {
        // Dedicated suite, wiped before each test — isolated from `.standard` and self-cleaning
        // (a fixed name means no per-run accumulation of orphaned preference files). `.serialized`
        // keeps the shared suite race-free across this struct's tests.
        userDefaults = UserDefaults(suiteName: Self.suiteName)!
        userDefaults.removePersistentDomain(forName: Self.suiteName)
    }

    // MARK: - didAuthenticate

    @Test
    func didAuthenticate_persistsCredentialsAndAuthenticates() {
        let store = MockKeychainStore()
        let manager = AuthManager(keychainStore: store, userDefaults: userDefaults)
        let creds = makeCredentials()

        manager.didAuthenticate(with: creds)

        #expect(store.saveCredentialsCallCount == 1)
        #expect(store.savedCredentials?.accessToken == creds.accessToken)
        #expect(manager.state == .authenticated)
        #expect(manager.credentials?.accessToken == creds.accessToken)
    }

    @Test
    func didAuthenticate_whenPersistFails_stillAttemptsSaveAndDoesNotCrash() {
        let store = MockKeychainStore(saveError: MockKeychainError())
        let manager = AuthManager(keychainStore: store, userDefaults: userDefaults)
        let creds = makeCredentials()

        manager.didAuthenticate(with: creds)

        // The throwing save seam was actually invoked (no silent `try?` swallow).
        #expect(store.saveCredentialsCallCount == 1)
        // Nothing was durably persisted despite the reported success.
        #expect(store.savedCredentials == nil)
        // Conservative behavior retained: the session is still usable this launch.
        #expect(manager.state == .authenticated)
    }

    // MARK: - clearKeychainIfReinstalled (exercised via init)

    @Test
    func init_firstLaunch_clearsKeychainAndSetsFlag() {
        let store = MockKeychainStore(storedCredentials: makeCredentials())

        _ = AuthManager(keychainStore: store, userDefaults: userDefaults)

        #expect(store.clearAllCallCount == 1)
        #expect(userDefaults.bool(forKey: AuthManager.hasLaunchedKey) == true)
    }

    @Test
    func init_firstLaunch_whenClearFails_doesNotSetFlag() {
        let store = MockKeychainStore(storedCredentials: makeCredentials(), clearError: MockKeychainError())

        _ = AuthManager(keychainStore: store, userDefaults: userDefaults)

        #expect(store.clearAllCallCount == 1)
        // Flag intentionally NOT set so the wipe is retried on the next launch.
        #expect(userDefaults.bool(forKey: AuthManager.hasLaunchedKey) == false)
    }

    @Test
    func init_subsequentLaunch_doesNotClearKeychain() {
        let store = MockKeychainStore(storedCredentials: makeCredentials())
        userDefaults.set(true, forKey: AuthManager.hasLaunchedKey)

        let manager = AuthManager(keychainStore: store, userDefaults: userDefaults)

        #expect(store.clearAllCallCount == 0)
        #expect(manager.state == .authenticated)
    }

    // MARK: - updateServerURL

    /**
     The whole point of validating before persisting: an address that answers but does not
     recognise this session must cost the user nothing. HA returns `invalid_grant` for an
     unknown refresh token, which the logout path reads as an expired session — that would
     revoke a still-valid token and wipe the Keychain over a typo.
    */
    @Test
    func updateServerURL_whenAddressRejectsTheToken_keepsSessionAndDoesNotClearKeychain() async {
        let store = MockKeychainStore()
        let manager = AuthManager(
            keychainStore: store,
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in throw AuthError.sessionExpired }
        )
        let creds = makeCredentials()
        manager.didAuthenticate(with: creds)
        let clearsBefore = store.clearAllCallCount // init performs the first-run wipe

        await #expect(throws: AuthError.differentServer) {
            try await manager.updateServerURL(to: URL(string: "https://someone-else.example.com")!)
        }

        #expect(manager.state == .authenticated)
        #expect(manager.credentials?.serverURL == creds.serverURL)
        #expect(store.clearAllCallCount == clearsBefore)
    }

    /// A flaky network must not be mistaken for a dead session either.
    @Test
    func updateServerURL_whenAddressUnreachable_keepsSessionAndDoesNotClearKeychain() async {
        let store = MockKeychainStore()
        let manager = AuthManager(
            keychainStore: store,
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in throw URLError(.cannotConnectToHost) }
        )
        let creds = makeCredentials()
        manager.didAuthenticate(with: creds)
        let clearsBefore = store.clearAllCallCount // init performs the first-run wipe

        await #expect(throws: AuthError.serverUnreachable) {
            try await manager.updateServerURL(to: URL(string: "http://192.168.1.254:8123")!)
        }

        #expect(manager.state == .authenticated)
        #expect(manager.credentials?.serverURL == creds.serverURL)
        #expect(store.clearAllCallCount == clearsBefore)
    }

    /// `clientId` stays pinned to the URL it was minted with, or future refreshes fail.
    @Test
    func updateServerURL_whenAccepted_persistsNewURLAndKeepsClientId() async throws {
        let store = MockKeychainStore()
        let manager = AuthManager(
            keychainStore: store,
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in
                TokenResponse(access_token: "new-access", refresh_token: nil, expires_in: 1800, token_type: "Bearer")
            }
        )
        let creds = makeCredentials()
        manager.didAuthenticate(with: creds)
        let newURL = URL(string: "http://box.tailnet.ts.net:8123")!

        try await manager.updateServerURL(to: newURL)

        #expect(manager.credentials?.serverURL == newURL)
        #expect(manager.credentials?.clientId == creds.clientId)
        #expect(manager.credentials?.accessToken == "new-access")
        #expect(manager.credentials?.refreshToken == creds.refreshToken)
        #expect(store.savedCredentials?.serverURL == newURL)
    }

    // MARK: - Session Expiry

    /// The server address must outlive the rejected token, so the user logs in again, not from scratch.
    @Test
    func validAccessToken_whenRefreshRejected_expiresSessionKeepingServerAddress() async {
        let store = MockKeychainStore()
        let manager = AuthManager(
            keychainStore: store,
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in throw AuthError.sessionExpired }
        )
        let creds = makeCredentials(expiresAt: .distantPast)
        manager.didAuthenticate(with: creds)
        let clearsBefore = store.clearAllCallCount
        var notified: [AuthState] = []
        manager.addOnChangeHandler { state, _ in notified.append(state) }

        await #expect(throws: AuthError.sessionExpired) {
            try await manager.validAccessToken()
        }

        #expect(manager.state == .sessionExpired)
        #expect(notified == [.sessionExpired])
        #expect(manager.credentials?.serverURL == creds.serverURL)
        #expect(store.savedCredentials?.serverURL == creds.serverURL)
        #expect(store.savedCredentials?.refreshToken == "")
        #expect(store.clearAllCallCount == clearsBefore)
    }

    /// Late token requests from the stopped session must not refresh with no token or re-notify.
    @Test
    func validAccessToken_whenSessionExpired_throwsWithoutNotifyingAgain() async {
        let manager = AuthManager(
            keychainStore: MockKeychainStore(),
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in throw AuthError.sessionExpired }
        )
        manager.didAuthenticate(with: makeCredentials(expiresAt: .distantPast))
        _ = try? await manager.validAccessToken()
        var notifyCount = 0
        manager.addOnChangeHandler { _, _ in notifyCount += 1 }

        await #expect(throws: AuthError.notAuthenticated) {
            try await manager.validAccessToken()
        }

        #expect(manager.state == .sessionExpired)
        #expect(notifyCount == 0)
    }

    @Test
    func init_withExpiredSessionStored_restoresSessionExpired() {
        var expired = makeCredentials()
        expired.accessToken = ""
        expired.refreshToken = ""
        userDefaults.set(true, forKey: AuthManager.hasLaunchedKey)

        let manager = AuthManager(keychainStore: MockKeychainStore(storedCredentials: expired), userDefaults: userDefaults)

        #expect(manager.state == .sessionExpired)
        #expect(manager.credentials?.serverURL == expired.serverURL)
    }

    @Test
    func didAuthenticate_afterExpiry_authenticates() async {
        let store = MockKeychainStore()
        let manager = AuthManager(
            keychainStore: store,
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in throw AuthError.sessionExpired }
        )
        manager.didAuthenticate(with: makeCredentials(expiresAt: .distantPast))
        _ = try? await manager.validAccessToken()

        manager.didAuthenticate(with: makeCredentials())

        #expect(manager.state == .authenticated)
        #expect(store.savedCredentials?.refreshToken == "refresh-token")
    }

    @Test
    func logout_afterExpiry_clearsKeychain() async {
        let store = MockKeychainStore()
        let manager = AuthManager(
            keychainStore: store,
            userDefaults: userDefaults,
            refreshToken: { _, _, _ in throw AuthError.sessionExpired }
        )
        manager.didAuthenticate(with: makeCredentials(expiresAt: .distantPast))
        _ = try? await manager.validAccessToken()
        let clearsBefore = store.clearAllCallCount

        manager.logout()

        #expect(manager.state == .unauthenticated)
        #expect(manager.credentials == nil)
        #expect(store.clearAllCallCount == clearsBefore + 1)
    }
}

// MARK: - Helpers

private extension AuthManagerTests {

    func makeCredentials(expiresAt: Date = Date().addingTimeInterval(3600)) -> ServerCredentials {
        ServerCredentials(
            serverURL: URL(string: "https://home.example.com:8123")!,
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenExpiresAt: expiresAt,
            clientId: "https://home.example.com:8123"
        )
    }
}
