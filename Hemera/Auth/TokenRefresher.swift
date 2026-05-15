import Foundation
import HemeraLog

actor TokenRefresher {

    private let keychainStore: KeychainStore
    private var refreshTask: Task<(String, ServerCredentials), Error>?

    init(keychainStore: KeychainStore) {
        self.keychainStore = keychainStore
    }

    func validToken(for credentials: ServerCredentials) async throws -> (String, ServerCredentials) {
        // If token still valid (60s buffer), return it
        if credentials.tokenExpiresAt.timeIntervalSinceNow > 60 {
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

            let response = try await TokenClient.refresh(
                refreshToken: credentials.refreshToken,
                clientId: credentials.clientId,
                serverURL: credentials.serverURL
            )

            var updated = credentials
            updated.accessToken = response.access_token
            updated.refreshToken = response.refresh_token ?? credentials.refreshToken
            updated.tokenExpiresAt = Date().addingTimeInterval(TimeInterval(response.expires_in))

            let credentialsToSave = updated
            let store = keychainStore
            await MainActor.run { store.saveCredentials(credentialsToSave) }
            return (updated.accessToken, updated)
        }
        refreshTask = task
        return try await task.value
    }
}
