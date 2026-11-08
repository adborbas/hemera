import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {

    enum Route: Hashable {
        case kioskMode
        case serverURL
        case account
    }

    var path = NavigationPath()
    var showLogoutConfirmation = false
    var showExitDemoConfirmation = false
    var showServerWebView = false
    var showConfetti = false
    private(set) var haVersion: String?

    let isDemoMode: Bool
    let screenManager: ScreenManager
    private let homeProfile: HomeProfile?
    private let authManager: any AuthManaging
    private let demoCoordinator: any DemoCoordinating
    private let restClient: (any HARESTClienting)?
    private var versionTapCount = 0
    private var pendingRoute: Route?

    init(
        authManager: any AuthManaging,
        demoCoordinator: any DemoCoordinating,
        screenManager: ScreenManager,
        restClient: (any HARESTClienting)?,
        homeProfile: HomeProfile?,
        initialRoute: Route? = nil
    ) {
        self.authManager = authManager
        self.isDemoMode = demoCoordinator.isActive
        self.demoCoordinator = demoCoordinator
        self.screenManager = screenManager
        self.restClient = restClient
        self.homeProfile = homeProfile
        self.pendingRoute = initialRoute
    }

    convenience init(initialRoute: Route? = nil) {
        let sl = ServiceLocator.shared
        self.init(
            authManager: sl.authManager,
            demoCoordinator: sl.demoCoordinator,
            screenManager: sl.screenManager,
            restClient: sl.session?.restClient,
            homeProfile: sl.session?.homeProfile,
            initialRoute: initialRoute
        )
    }

    var isAccountPageAvailable: Bool { !isDemoMode }

    var account: Account? { homeProfile?.account }

    /// Falls back to the server host, then "Account", while the user hasn't loaded or failed to.
    var accountName: String {
        if isDemoMode { return Localization.demo }
        if let name = account?.name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return logoutHost ?? Localization.account
    }

    /// "Role · Home name"; demo mode shows only the home.
    var accountSubtitle: String {
        let role = isDemoMode ? nil : account?.role.displayName
        return [role, homeProfile?.displayName].compactMap { $0 }.joined(separator: " · ")
    }

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

    func exitDemoTapped() {
        showExitDemoConfirmation = true
    }

    func confirmExitDemo() {
        demoCoordinator.exit()
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

private extension SettingsViewModel {
    enum Localization {
        static let demo = String(localized: "Demo", comment: "Account row title in settings while the app runs in demo mode")
        static let account = String(
            localized: "Account",
            comment: "Account row title in settings until the signed-in user's name is known"
        )
    }
}
