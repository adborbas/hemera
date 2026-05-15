import Foundation
import Testing
@testable import Hemera

@MainActor
struct ConnectingViewModelTests {

    static let testServerURL = URL(string: "https://ha.example.com:8123")!

    static var testCredentials: ServerCredentials {
        ServerCredentials(
            serverURL: testServerURL,
            accessToken: "test-token",
            refreshToken: "test-refresh",
            tokenExpiresAt: .distantFuture,
            clientId: "test-client"
        )
    }

    let viewModel: ConnectingViewModel
    let authManager: MockAuthManager
    let retrier: MockConnectionRetrier

    init() {
        authManager = MockAuthManager()
        retrier = MockConnectionRetrier()
        viewModel = ConnectingViewModel(authManager: authManager, connectionRetrier: retrier)
    }

    // MARK: - Server Host

    @Test
    func serverHost_whenAuthenticated_returnsHost() {
        authManager.didAuthenticate(with: Self.testCredentials)
        #expect(viewModel.serverHost == "ha.example.com")
    }

    @Test
    func serverHost_whenNotAuthenticated_returnsFallback() {
        #expect(viewModel.serverHost == "server")
    }

    // MARK: - Timeout

    @Test
    func startTimeout_setsTimedOutToFalse() {
        viewModel.startTimeout()
        #expect(viewModel.timedOut == false)
    }

    @Test
    func cancelTimeout_preventsTimeout() async {
        viewModel.startTimeout()
        viewModel.cancelTimeout()

        await viewModel.timeoutTask?.value
        #expect(viewModel.timedOut == false)
    }

    // MARK: - Retry

    @Test
    func retry_callsConnectionRetrier() {
        viewModel.retry()

        #expect(retrier.retryCallCount == 1)
    }
}
