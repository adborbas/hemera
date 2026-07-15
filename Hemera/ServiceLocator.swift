import Foundation

@MainActor
final class ServiceLocator {

    let authManager: any AuthManaging
    let router: AppRouter
    let demoCoordinator: any DemoCoordinating
    let sessionManager: SessionManager
    let screenManager: ScreenManager
    let areaDisplaySettings: AreaDisplaySettings
    var appCoordinator: AppCoordinator?

    /// Session-scoped dependencies. Non-nil when a session (HA or demo) is active.
    var session: Session?

    nonisolated(unsafe) private static var _shared: ServiceLocator?

    nonisolated static var shared: ServiceLocator {
        guard let instance = _shared else {
            preconditionFailure("ServiceLocator.configure() must be called before accessing .shared")
        }
        return instance
    }

    static func configure(
        authManager: any AuthManaging,
        router: AppRouter,
        demoCoordinator: any DemoCoordinating,
        sessionManager: SessionManager,
        screenManager: ScreenManager,
        areaDisplaySettings: AreaDisplaySettings
    ) {
        _shared = ServiceLocator(
            authManager: authManager,
            router: router,
            demoCoordinator: demoCoordinator,
            sessionManager: sessionManager,
            screenManager: screenManager,
            areaDisplaySettings: areaDisplaySettings
        )
    }

    private init(authManager: any AuthManaging, router: AppRouter, demoCoordinator: any DemoCoordinating, sessionManager: SessionManager, screenManager: ScreenManager, areaDisplaySettings: AreaDisplaySettings) {
        self.authManager = authManager
        self.router = router
        self.demoCoordinator = demoCoordinator
        self.sessionManager = sessionManager
        self.screenManager = screenManager
        self.areaDisplaySettings = areaDisplaySettings
    }

    #if DEBUG
    static func configureForPreview(authenticated: Bool = true, demoMode: Bool = false) {
        let authManager = AuthManager()
        let router = AppRouter(authManager: authManager)
        let env = AppEnvironment()
        let sessionManager = SessionManager(
            authManager: authManager,
            router: router,
            container: env.container,
            storage: env.storage
        )
        let demoCoordinator = DemoCoordinator()

        configure(
            authManager: authManager,
            router: router,
            demoCoordinator: demoCoordinator,
            sessionManager: sessionManager,
            screenManager: env.screenManager,
            areaDisplaySettings: env.areaDisplaySettings
        )

        if authenticated {
            authManager.didAuthenticate(with: ServerCredentials(
                serverURL: URL(string: "http://192.168.1.100:8123")!,
                accessToken: "preview",
                refreshToken: "preview",
                tokenExpiresAt: .distantFuture,
                clientId: "http://192.168.1.100:8123"
            ))
        }

        if demoMode {
            demoCoordinator.enter()
        }
    }
    #endif
}
