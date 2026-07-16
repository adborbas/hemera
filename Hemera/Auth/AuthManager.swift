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

    private let keychainStore: any KeychainStoring
    private let tokenRefresher: TokenRefresher
    private var onChangeHandlers: [(AuthState, AuthChangeReason) -> Void] = []

    init(keychainStore: any KeychainStoring, userDefaults: UserDefaults = .standard) {
        self.keychainStore = keychainStore
        self.tokenRefresher = TokenRefresher(keychainStore: keychainStore)

        Self.clearKeychainIfReinstalled(keychainStore: keychainStore, userDefaults: userDefaults)

        if let creds = keychainStore.loadCredentials() {
            credentials = creds
            state = .authenticated
        }
    }

    convenience init() {
        self.init(keychainStore: KeychainStore.shared)
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
        do {
            try keychainStore.saveCredentials(creds)
        } catch {
            Log.error("Failed to persist credentials — session will not survive relaunch", cause: error)
        }
        credentials = creds
        state = .authenticated
        onChangeHandlers.forEach { $0(.authenticated, .userInitiated) }
    }

    func logout() {
        performLogout(reason: .userInitiated)
    }

    // Internal (not private) so tests can reference the same key instead of duplicating the literal.
    static let hasLaunchedKey = "com.hemera.hasLaunchedBefore"
}

// MARK: - Private Methods

private extension AuthManager {

    /**
     Clears stale keychain credentials left over from a previous install.
     iOS preserves keychain items across app uninstall/reinstall, but
     UserDefaults are wiped. If the flag is missing, this is a fresh install.

     Trade-off (accepted knowingly): freshness is inferred only from the missing
     flag, which is equally absent for a legitimate upgrade from a build that
     predated this flag — so such an upgrade triggers a one-time logout. We accept
     that for the safer security posture (never inherit foreign credentials).
     Gating the wipe on install-identity is not reliably possible from the Keychain
     alone without risking a reinstall inheriting a previous user's credentials.
     */
    static func clearKeychainIfReinstalled(keychainStore: any KeychainStoring, userDefaults: UserDefaults) {
        guard !userDefaults.bool(forKey: hasLaunchedKey) else { return }
        do {
            try keychainStore.clearAll()
            userDefaults.set(true, forKey: hasLaunchedKey) // only mark done if the wipe actually happened
        } catch {
            Log.error("First-run keychain wipe failed — will retry next launch", cause: error)
            // Flag intentionally NOT set, so the wipe is retried on the next launch.
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
        do {
            try keychainStore.clearAll()
        } catch {
            Log.warning("Failed to clear credentials on logout", cause: error)
        }
        credentials = nil
        state = .unauthenticated
        onChangeHandlers.forEach { $0(.unauthenticated, reason) }
    }
}
