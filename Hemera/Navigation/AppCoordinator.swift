import Foundation

/// Owns the tab-level view models for the authenticated UI.
///
/// `MainTabView`'s `@State` properties can't construct the VMs themselves
/// without firing the constructor on every view re-init (SwiftUI's
/// `State<Value>` takes a value, not an autoclosure). Constructing them
/// here, once per session, gives the VMs a stable identity across view
/// re-evaluations and keeps the data-layer (`SessionManager`) free of
/// presentation concerns.
@MainActor
final class AppCoordinator: DemoCoordinatorDelegate {

    private(set) var tabViewModels: TabViewModels?

    private let sessionManager: SessionManager
    private let authManager: any AuthManaging
    private let router: AppRouter

    init(sessionManager: SessionManager, authManager: any AuthManaging, router: AppRouter) {
        self.sessionManager = sessionManager
        self.authManager = authManager
        self.router = router

        // SessionManager registered its auth handler first (during its init),
        // so by the time our handler runs the `Session` has been published
        // to `ServiceLocator`.
        authManager.addOnChangeHandler { [weak self] state, _ in
            switch state {
            case .authenticated:
                self?.buildTabViewModels()
            case .unauthenticated:
                self?.tabViewModels = nil
            }
        }
    }

    /// Called from `HemeraApp` after `SessionManager.startIfAuthenticated()`.
    /// Auth-state didn't transition, so the `addOnChangeHandler` callback
    /// above won't fire — we need to bootstrap the VMs explicitly.
    func startIfAuthenticated() {
        if authManager.state == .authenticated {
            buildTabViewModels()
        }
    }

    func demoDidEnter() {
        sessionManager.startDemoSession()
        buildTabViewModels()
        router.navigate(to: .authenticated)
    }

    func demoDidExit(connectToServer: Bool) {
        tabViewModels = nil
        sessionManager.tearDownDemoSession()
        router.navigate(to: connectToServer ? .connectToServer : .onboarding)
    }

    private func buildTabViewModels() {
        guard let session = ServiceLocator.shared.session else { return }
        tabViewModels = TabViewModels(
            session: session,
            authManager: authManager,
            demoCoordinator: ServiceLocator.shared.demoCoordinator,
            connectionRetrier: sessionManager
        )
    }
}

/// Single-instance container for the tab-level VMs.
/// Reference type so multiple `MainTabView` re-evaluations see the same VMs.
@MainActor
final class TabViewModels {
    let curatedHome: CuratedHomeViewModel
    let areas: AreasViewModel
    let settings: SettingsViewModel

    init(
        session: Session,
        authManager: any AuthManaging,
        demoCoordinator: any DemoCoordinating,
        connectionRetrier: any ConnectionRetrying
    ) {
        self.curatedHome = CuratedHomeViewModel(
            homeTileRepository: session.homeTileRepository,
            viewModelFactory: session.viewModelFactory,
            authManager: authManager,
            demoCoordinator: demoCoordinator,
            errorNotifier: session.errorNotifier,
            connectionRetrier: connectionRetrier,
            resync: session.resync
        )
        self.areas = AreasViewModel(
            homeTileRepository: session.homeTileRepository,
            viewModelFactory: session.viewModelFactory,
            demoCoordinator: demoCoordinator,
            authManager: authManager,
            errorNotifier: session.errorNotifier,
            connectionRetrier: connectionRetrier,
            resync: session.resync
        )
        self.settings = SettingsViewModel(
            authManager: authManager,
            demoCoordinator: demoCoordinator,
            screenManager: ServiceLocator.shared.screenManager,
            restClient: session.restClient
        )
    }
}
