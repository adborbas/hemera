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
            screenManager: ScreenManager(store: InMemorySettingsStore()),
            restClient: nil,
            homeProfile: nil
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
            screenManager: ScreenManager(store: InMemorySettingsStore()),
            restClient: nil,
            homeProfile: nil
        )
        #expect(vm.isDemoMode == true)
    }

    @Test
    func exitDemoTapped_asksForConfirmationBeforeExiting() {
        viewModel.exitDemoTapped()

        #expect(viewModel.showExitDemoConfirmation == true)
        #expect(demoCoordinator.exitCallCount == 0)
    }

    @Test
    func confirmExitDemo_exitsDemo() {
        demoCoordinator.enter()
        viewModel.confirmExitDemo()

        #expect(demoCoordinator.exitCallCount == 1)
        #expect(demoCoordinator.isActive == false)
    }

    // MARK: - Account Row

    @Test
    func accountSubtitle_live_showsLocalizedRoleAndHomeName() {
        // The row answers "who is signed in where", so it needs both the role and the home.
        let vm = makeViewModel(homeProfile: HomeProfile(
            homeName: "Lake House",
            account: Account(name: "Alex Morgan", role: .admin, pictureURL: nil)
        ))

        #expect(vm.accountName == "Alex Morgan")
        #expect(vm.accountSubtitle == "Administrator · Lake House")
    }

    @Test
    func accountSubtitle_withoutHomeName_fallsBackToHomeLikeTheHeader() {
        // The header shows "Home" for an unnamed home; Settings must name it the same way.
        let profile = HomeProfile(homeName: nil, account: Account(name: "Alex", role: .owner, pictureURL: nil))

        #expect(makeViewModel(homeProfile: profile).accountSubtitle == "Owner · Home")
    }

    @Test
    func accountName_beforeAccountLoads_showsServerHost() {
        // The user request can still be in flight or fail; the row must never read blank.
        authManager.didAuthenticate(with: Self.testCredentials)
        let vm = makeViewModel(homeProfile: HomeProfile())

        #expect(vm.accountName == "ha.example.com")
        #expect(vm.accountSubtitle == "Home")
    }

    @Test
    func accountRow_live_opensAccountPage() {
        // Server details and Log Out live only on the Account page.
        #expect(makeViewModel(homeProfile: HomeProfile()).isAccountPageAvailable == true)
    }

    @Test
    func accountRow_inDemo_readsDemoWithoutRoleOrAccountPage() {
        // Demo data has a fake owner; the row must not pretend a real account is signed in.
        demoCoordinator.enter()
        let vm = makeViewModel(homeProfile: HomeProfile(
            homeName: "Hemera Home",
            account: Account(name: "Alex Morgan", role: .owner, pictureURL: nil)
        ))

        #expect(vm.accountName == "Demo")
        #expect(vm.accountSubtitle == "Hemera Home")
        #expect(vm.isAccountPageAvailable == false)
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
            screenManager: ScreenManager(store: InMemorySettingsStore()),
            restClient: restClient,
            homeProfile: nil
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

    private func makeViewModel(homeProfile: HomeProfile?) -> SettingsViewModel {
        SettingsViewModel(
            authManager: authManager,
            demoCoordinator: demoCoordinator,
            screenManager: ScreenManager(store: InMemorySettingsStore()),
            restClient: nil,
            homeProfile: homeProfile
        )
    }
}
