import Foundation

/// Orchestrates the OAuth2 flow with Home Assistant.
///
/// Uses the server URL as client_id and a same-origin redirect_uri so HA accepts
/// the request without needing a hosted client_id page with a `<link>` tag.
/// The actual redirect is intercepted by OAuthWebView (WKWebView) before navigating.
final class OAuthFlowManager {

    struct AuthSession: Identifiable {
        let id = UUID()
        let authorizeURL: URL
        let redirectURI: String
        let state: String
        let clientId: String
        let serverURL: URL
    }

    /// Builds the authorize URL and returns an AuthSession for the web view to use.
    func prepare(serverURL: URL) throws -> AuthSession {
        try validateServerURL(serverURL)

        let clientId = serverURL.absoluteString
        let state = UUID().uuidString

        // Same-origin redirect URI — HA accepts without fetching client_id
        guard var redirectComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidServerURL
        }

        /**
         Preserve any base path (e.g. subpath-hosted HA behind a reverse proxy)
         by appending endpoint paths instead of replacing the server URL's path.
         */
        let rawBasePath = redirectComponents.path
        let basePath = rawBasePath.hasSuffix("/") ? String(rawBasePath.dropLast()) : rawBasePath

        redirectComponents.path = basePath + "/hemera_callback"
        redirectComponents.queryItems = nil
        redirectComponents.fragment = nil
        guard let redirectURL = redirectComponents.url else {
            throw AuthError.invalidServerURL
        }
        let redirectURI = redirectURL.absoluteString

        guard var authComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidServerURL
        }
        authComponents.path = basePath + "/auth/authorize"
        authComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authorizeURL = authComponents.url else {
            throw AuthError.invalidServerURL
        }

        return AuthSession(
            authorizeURL: authorizeURL,
            redirectURI: redirectURI,
            state: state,
            clientId: clientId,
            serverURL: serverURL
        )
    }

    /// Validates the callback URL and exchanges the auth code for tokens.
    func handleCallback(url: URL, session: AuthSession) async throws -> ServerCredentials {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthError.unknownCallback
        }
        let queryItems = components.queryItems ?? []
        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
              returnedState == session.state else {
            throw AuthError.stateMismatch
        }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw AuthError.noAuthCode
        }

        let tokenResponse = try await TokenClient.exchangeCode(
            code: code,
            clientId: session.clientId,
            serverURL: session.serverURL
        )

        return ServerCredentials(
            serverURL: session.serverURL,
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? "",
            tokenExpiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in)),
            clientId: session.clientId
        )
    }

    // MARK: - Private

    private func validateServerURL(_ url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidServerURL
        }
        guard let scheme = components.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            throw AuthError.invalidServerURL
        }
        guard let host = components.host, !host.isEmpty else {
            throw AuthError.invalidServerURL
        }
        // Reject URLs with user/password components (authority confusion attack vector)
        if components.user != nil || components.password != nil {
            throw AuthError.invalidServerURL
        }
    }
}
