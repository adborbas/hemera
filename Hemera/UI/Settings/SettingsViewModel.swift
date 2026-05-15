import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {

    enum Route: Hashable {
        case kioskMode
    }

    var path = NavigationPath()
    var showLogoutConfirmation = false
    var showServerWebView = false
    var showConfetti = false
    private(set) var haVersion: String?

    let isDemoMode: Bool
    let bannerViewModel: DemoModeBannerViewModel
    let screenManager: ScreenManager
    private let authManager: any AuthManaging
    private let restClient: (any HARESTClienting)?
    private var versionTapCount = 0
    private var pendingRoute: Route?

    init(
        authManager: any AuthManaging,
        demoCoordinator: any DemoCoordinating,
        screenManager: ScreenManager,
        restClient: (any HARESTClienting)?,
        initialRoute: Route? = nil
    ) {
        self.authManager = authManager
        self.isDemoMode = demoCoordinator.isActive
        self.bannerViewModel = DemoModeBannerViewModel(demoCoordinator: demoCoordinator)
        self.screenManager = screenManager
        self.restClient = restClient
        self.pendingRoute = initialRoute
    }

    convenience init(initialRoute: Route? = nil) {
        let sl = ServiceLocator.shared
        self.init(
            authManager: sl.authManager,
            demoCoordinator: sl.demoCoordinator,
            screenManager: sl.screenManager,
            restClient: sl.session?.restClient,
            initialRoute: initialRoute
        )
    }

    var isShowingDemoModeHeader: Bool { isDemoMode }
    var isShowingServerInfoSection: Bool { !isDemoMode }
    var isShowingLogoutSection: Bool { !isDemoMode }

    var serverURL: URL? { authManager.credentials?.serverURL }
    var logoutHost: String? { authManager.credentials?.serverURL.host() }

    func validAccessToken() async throws -> String {
        try await authManager.validAccessToken()
    }

    func openServer() {
        showServerWebView = true
    }

    func closeServer() {
        showServerWebView = false
    }

    func logoutTapped() {
        showLogoutConfirmation = true
    }

    func confirmLogout() {
        authManager.logout()
    }

    func versionTapped() {
        versionTapCount += 1
        if versionTapCount >= 3 {
            versionTapCount = 0
            showConfetti = true
        }
    }

    func confettiFinished() {
        showConfetti = false
    }

    func navigateToPendingRoute() {
        if let route = pendingRoute {
            pendingRoute = nil
            path.append(route)
        }
    }

    func navigateToRoute(_ route: Route) {
        path = NavigationPath()
        path.append(route)
    }

    func fetchHAVersion() async {
        haVersion = await restClient?.fetchVersion()
    }
}
