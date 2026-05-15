import Foundation
import Testing
@testable import Hemera

@MainActor
struct SettingsViewModelTests {

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

    let viewModel: SettingsViewModel
    let authManager: MockAuthManager
    let demoCoordinator: MockDemoCoordinator

    init() {
        authManager = MockAuthManager()
        demoCoordinator = MockDemoCoordinator()
        viewModel = SettingsViewModel(
            authManager: authManager,
            demoCoordinator: demoCoordinator,
            screenManager: ScreenManager(),
            restClient: nil
        )
    }

    // MARK: - Demo Mode

    @Test
    func isDemoMode_whenDemoCoordinatorInactive_isFalse() {
        #expect(viewModel.isDemoMode == false)
    }

    @Test
    func isDemoMode_whenDemoCoordinatorActive_isTrue() {
        demoCoordinator.enter()
        let vm = SettingsViewModel(
            authManager: authManager,
            demoCoordinator: demoCoordinator,
            screenManager: ScreenManager(),
            restClient: nil
        )
        #expect(vm.isDemoMode == true)
    }

    // MARK: - Credentials

    @Test
    func serverURL_whenAuthenticated_returnsURL() {
        authManager.didAuthenticate(with: Self.testCredentials)
        #expect(viewModel.serverURL == Self.testServerURL)
    }

    @Test
    func serverURL_whenNotAuthenticated_returnsNil() {
        #expect(viewModel.serverURL == nil)
    }

    @Test
    func logoutHost_whenAuthenticated_returnsHost() {
        authManager.didAuthenticate(with: Self.testCredentials)
        #expect(viewModel.logoutHost == "ha.example.com")
    }

    @Test
    func logoutHost_whenNotAuthenticated_returnsNil() {
        #expect(viewModel.logoutHost == nil)
    }

    // MARK: - Server Web View

    @Test
    func openServer_setsShowServerWebViewToTrue() {
        viewModel.openServer()
        #expect(viewModel.showServerWebView == true)
    }

    @Test
    func closeServer_setsShowServerWebViewToFalse() {
        viewModel.openServer()
        viewModel.closeServer()
        #expect(viewModel.showServerWebView == false)
    }

    // MARK: - Logout

    @Test
    func logoutTapped_setsShowLogoutConfirmationToTrue() {
        viewModel.logoutTapped()
        #expect(viewModel.showLogoutConfirmation == true)
    }

    @Test
    func confirmLogout_logsOutAuthManager() {
        authManager.didAuthenticate(with: Self.testCredentials)

        viewModel.confirmLogout()

        #expect(authManager.logoutCallCount == 1)
        #expect(authManager.state == .unauthenticated)
    }

    // MARK: - HA Version

    @Test
    func fetchHAVersion_setsVersionFromRESTClient() async {
        let restClient = MockRESTClient()
        restClient.stubbedVersion = "2025.1.0"
        let vm = SettingsViewModel(
            authManager: authManager,
            demoCoordinator: demoCoordinator,
            screenManager: ScreenManager(),
            restClient: restClient
        )

        await vm.fetchHAVersion()

        #expect(vm.haVersion == "2025.1.0")
        #expect(restClient.fetchVersionCallCount == 1)
    }

    @Test
    func fetchHAVersion_withNilRestClient_leavesVersionNil() async {
        await viewModel.fetchHAVersion()

        #expect(viewModel.haVersion == nil)
    }
}
