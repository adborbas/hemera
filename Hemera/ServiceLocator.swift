import Foundation

@MainActor
final class ServiceLocator {

    let authManager: any AuthManaging
    let router: AppRouter
    let demoCoordinator: any DemoCoordinating
    let sessionManager: SessionManager
    let screenManager: ScreenManager
    let settings: UserSettings
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
        settings: UserSettings
    ) {
        _shared = ServiceLocator(
            authManager: authManager,
            router: router,
            demoCoordinator: demoCoordinator,
            sessionManager: sessionManager,
            screenManager: screenManager,
            settings: settings
        )
    }

    private init(authManager: any AuthManaging, router: AppRouter, demoCoordinator: any DemoCoordinating, sessionManager: SessionManager, screenManager: ScreenManager, settings: UserSettings) {
        self.authManager = authManager
        self.router = router
        self.demoCoordinator = demoCoordinator
        self.sessionManager = sessionManager
        self.screenManager = screenManager
        self.settings = settings
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
            settings: env.settings
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
