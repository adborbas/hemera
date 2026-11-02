import Foundation

/// Turns demo-mode enter and exit into session changes and navigation.
@MainActor
final class AppCoordinator: DemoCoordinatorDelegate {

    private let sessionManager: SessionManager
    private let router: AppRouter

    init(sessionManager: SessionManager, router: AppRouter) {
        self.sessionManager = sessionManager
        self.router = router
    }

    func demoDidEnter() {
        sessionManager.startDemoSession()
        router.navigate(to: .authenticated)
    }

    func demoDidExit(connectToServer: Bool) {
        sessionManager.tearDownDemoSession()
        router.navigate(to: connectToServer ? .connectToServer : .onboarding)
    }
}
