import Foundation
import Testing
@testable import Hemera

@MainActor
struct AppCoordinatorTests {

    let coordinator: AppCoordinator
    let router: AppRouter

    init() {
        let authManager = AuthManager(keychainStore: KeychainStore(service: "com.hemera.test.\(UUID().uuidString)"))
        router = AppRouter(authManager: authManager)
        let env = AppEnvironment()
        let sessionManager = SessionManager(authManager: authManager, router: router, container: env.container, storage: env.storage)

        ServiceLocator.configure(
            authManager: authManager,
            router: router,
            demoCoordinator: DemoCoordinator(),
            sessionManager: sessionManager,
            screenManager: env.screenManager
        )

        coordinator = AppCoordinator(sessionManager: sessionManager, authManager: authManager, router: router)
    }

    // MARK: - demoDidEnter

    @Test
    func demoDidEnter_navigatesToAuthenticated() {
        coordinator.demoDidEnter()

        #expect(router.destination == .authenticated)
    }

    // MARK: - demoDidExit

    @Test
    func demoDidExit_withConnectToServerFalse_navigatesToOnboarding() {
        coordinator.demoDidEnter()

        coordinator.demoDidExit(connectToServer: false)

        #expect(router.destination == .onboarding)
    }

    @Test
    func demoDidExit_withConnectToServerTrue_navigatesToConnectToServer() {
        coordinator.demoDidEnter()

        coordinator.demoDidExit(connectToServer: true)

        #expect(router.destination == .connectToServer)
    }
}
