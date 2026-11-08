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
            screenManager: env.screenManager,
            settingsStore: env.settingsStore
        )

        coordinator = AppCoordinator(sessionManager: sessionManager, router: router)
    }

    // MARK: - demoDidEnter

    @Test
    func demoDidEnter_navigatesToAuthenticated() {
        coordinator.demoDidEnter()

        #expect(router.destination == .authenticated)
    }

    // MARK: - demoDidExit

    @Test
    func demoDidExit_navigatesToOnboarding() {
        coordinator.demoDidEnter()

        coordinator.demoDidExit()

        #expect(router.destination == .onboarding)
    }
}
