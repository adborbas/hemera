import Foundation
import HemeraLog

actor TokenRefresher {

    private let keychainStore: any KeychainStoring
    private let refreshToken: @Sendable (_ refreshToken: String, _ clientId: String, _ serverURL: URL) async throws -> TokenResponse
    /// Injected so a test can pin the expiry buffer without racing the wall clock.
    private let now: @Sendable () -> Date
    private var refreshTask: Task<(String, ServerCredentials), Error>?

    init(
        keychainStore: any KeychainStoring,
        refreshToken: @escaping @Sendable (String, String, URL) async throws -> TokenResponse = {
            try await TokenClient.refresh(refreshToken: $0, clientId: $1, serverURL: $2)
        },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.keychainStore = keychainStore
        self.refreshToken = refreshToken
        self.now = now
    }

    func validToken(for credentials: ServerCredentials) async throws -> (String, ServerCredentials) {
        // If token still valid (60s buffer), return it
        if credentials.tokenExpiresAt.timeIntervalSince(now()) > 60 {
            return (credentials.accessToken, credentials)
        }

        // Coalesce concurrent refresh calls
        if let existing = refreshTask {
            Log.debug("Token refresh already in progress — coalescing")
            return try await existing.value
        }

        Log.info("Token expired — refreshing")
        let task = Task<(String, ServerCredentials), Error> {
            defer { refreshTask = nil }

            let response = try await refreshToken(
                credentials.refreshToken,
                credentials.clientId,
                credentials.serverURL
            )

            var updated = credentials
            updated.accessToken = response.access_token
            updated.refreshToken = response.refresh_token ?? credentials.refreshToken
            updated.tokenExpiresAt = now().addingTimeInterval(TimeInterval(response.expires_in))

            do {
                try keychainStore.saveCredentials(updated)
            } catch {
                Log.error("Failed to persist refreshed credentials", cause: error)
            }
            return (updated.accessToken, updated)
        }
        refreshTask = task
        return try await task.value
    }
}
