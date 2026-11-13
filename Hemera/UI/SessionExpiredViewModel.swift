import Foundation

@Observable
@MainActor
final class SessionExpiredViewModel {

    var authSession: OAuthFlowManager.AuthSession?
    var showLogOutConfirmation = false
    var errorMessage: String?

    var serverHost: String {
        authManager.credentials?.serverURL.host() ?? "server"
    }

    private let oauthManager = OAuthFlowManager()
    private let authManager: any AuthManaging

    init(authManager: any AuthManaging) {
        self.authManager = authManager
    }

    convenience init() {
        self.init(authManager: ServiceLocator.shared.authManager)
    }

    func logIn() {
        errorMessage = nil
        guard let serverURL = authManager.credentials?.serverURL,
              let session = try? oauthManager.prepare(serverURL: serverURL) else {
            errorMessage = Localization.logInFailed(serverHost)
            return
        }
        authSession = session
    }

    func handleOAuthCallback(url: URL, session: OAuthFlowManager.AuthSession) async {
        do {
            let creds = try await oauthManager.handleCallback(url: url, session: session)
            authManager.didAuthenticate(with: creds)
        } catch {
            errorMessage = Localization.logInFailed(serverHost)
        }
    }

    func authSessionFailed() {
        authSession = nil
        errorMessage = Localization.logInFailed(serverHost)
    }

    func cancelAuth() {
        authSession = nil
    }

    func confirmLogOut() {
        authManager.logout()
    }
}

private extension SessionExpiredViewModel {
    enum Localization {
        static func logInFailed(_ host: String) -> String {
            String(
                localized: "Couldn't log in to \(host). Please try again.",
                comment: "Error shown on the Session expired screen when logging in again fails, with the server hostname"
            )
        }
    }
}
