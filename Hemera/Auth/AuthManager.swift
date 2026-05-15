import Foundation
import HemeraLog

enum AuthState {
    case unauthenticated
    case authenticated
}

enum AuthChangeReason {
    case userInitiated
    case sessionExpired
}

@MainActor
protocol AuthManaging: AnyObject {
    var state: AuthState { get }
    var credentials: ServerCredentials? { get }
    func addOnChangeHandler(_ handler: @escaping (AuthState, AuthChangeReason) -> Void)
    func didAuthenticate(with creds: ServerCredentials)
    func validAccessToken() async throws -> String
    func logout()
}

@Observable
@MainActor
final class AuthManager: AuthManaging {

    private(set) var state: AuthState = .unauthenticated
    private(set) var credentials: ServerCredentials?

    private let keychainStore: KeychainStore
    private let tokenRefresher: TokenRefresher
    private var onChangeHandlers: [(AuthState, AuthChangeReason) -> Void] = []

    init(keychainStore: KeychainStore, userDefaults: UserDefaults = .standard) {
        self.keychainStore = keychainStore
        self.tokenRefresher = TokenRefresher(keychainStore: keychainStore)

        Self.clearKeychainIfReinstalled(keychainStore: keychainStore, userDefaults: userDefaults)

        if let creds = keychainStore.loadCredentials() {
            credentials = creds
            state = .authenticated
        }
    }

    convenience init() {
        self.init(keychainStore: .shared)
    }

    func addOnChangeHandler(_ handler: @escaping (AuthState, AuthChangeReason) -> Void) {
        onChangeHandlers.append(handler)
    }

    func validAccessToken() async throws -> String {
        guard let creds = credentials else {
            Log.error("Token requested but no credentials available")
            throw AuthError.notAuthenticated
        }
        do {
            let (token, updatedCreds) = try await tokenRefresher.validToken(for: creds)
            credentials = updatedCreds
            return token
        } catch AuthError.sessionExpired {
            Log.warning("Session expired — forcing logout")
            performLogout(reason: .sessionExpired)
            throw AuthError.sessionExpired
        }
    }

    func didAuthenticate(with creds: ServerCredentials) {
        Log.info("Authenticated with \(creds.serverURL.host() ?? "unknown")")
        keychainStore.saveCredentials(creds)
        credentials = creds
        state = .authenticated
        onChangeHandlers.forEach { $0(.authenticated, .userInitiated) }
    }

    func logout() {
        performLogout(reason: .userInitiated)
    }
}

// MARK: - Private Methods

private extension AuthManager {

    private static let hasLaunchedKey = "com.hemera.hasLaunchedBefore"

    /// Clears stale keychain credentials left over from a previous install.
    /// iOS preserves keychain items across app uninstall/reinstall, but
    /// UserDefaults are wiped. If the flag is missing, this is a fresh install.
    static func clearKeychainIfReinstalled(keychainStore: KeychainStore, userDefaults: UserDefaults) {
        if !userDefaults.bool(forKey: hasLaunchedKey) {
            keychainStore.clearAll()
            userDefaults.set(true, forKey: hasLaunchedKey)
        }
    }

    func performLogout(reason: AuthChangeReason) {
        Log.info("Logging out (reason: \(reason))")
        if let creds = credentials {
            Task {
                do {
                    try await TokenClient.revoke(refreshToken: creds.refreshToken, serverURL: creds.serverURL)
                } catch {
                    Log.warning("Token revocation failed (non-blocking)", cause: error)
                }
            }
        }
        keychainStore.clearAll()
        credentials = nil
        state = .unauthenticated
        onChangeHandlers.forEach { $0(.unauthenticated, reason) }
    }
}
