import Foundation
import Testing
@testable import Hemera

@MainActor
struct SessionExpiredViewModelTests {

    static let testServerURL = URL(string: "https://ha.example.com:8123")!

    let viewModel: SessionExpiredViewModel
    let authManager: MockAuthManager

    init() {
        authManager = MockAuthManager()
        authManager.didAuthenticate(with: ServerCredentials(
            serverURL: Self.testServerURL,
            accessToken: "test-token",
            refreshToken: "test-refresh",
            tokenExpiresAt: .distantFuture,
            clientId: "test-client"
        ))
        authManager.simulateSessionExpiry()
        viewModel = SessionExpiredViewModel(authManager: authManager)
    }

    @Test
    func serverHost_namesStoredServer() {
        #expect(viewModel.serverHost == "ha.example.com")
    }

    /// Logging in again must go to the server the Home belongs to, not ask for an address.
    @Test
    func logIn_opensLoginPageForStoredServer() {
        viewModel.logIn()

        #expect(viewModel.authSession?.serverURL == Self.testServerURL)
        #expect(viewModel.authSession?.authorizeURL.host() == "ha.example.com")
    }

    @Test
    func cancelAuth_closesLoginPageWithoutLoggingInOrOut() {
        viewModel.logIn()

        viewModel.cancelAuth()

        #expect(viewModel.authSession == nil)
        #expect(authManager.state == .sessionExpired)
        #expect(authManager.logoutCallCount == 0)
        #expect(authManager.didAuthenticateCallCount == 1)
    }

    @Test
    func handleOAuthCallback_whenCallbackFails_setsErrorMessageAndDoesNotAuthenticate() async throws {
        viewModel.logIn()
        let session = try #require(viewModel.authSession)
        let callbackURL = URL(string: "https://ha.example.com:8123/hemera_callback?state=wrong&code=abc")!

        await viewModel.handleOAuthCallback(url: callbackURL, session: session)

        #expect(viewModel.errorMessage != nil)
        #expect(authManager.didAuthenticateCallCount == 1)
        #expect(authManager.state == .sessionExpired)
    }

    @Test
    func confirmLogOut_logsOut() {
        viewModel.confirmLogOut()

        #expect(authManager.logoutCallCount == 1)
    }
}
