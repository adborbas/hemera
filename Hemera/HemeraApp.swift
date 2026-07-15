import SwiftUI
import SwiftData
import HemeraLog

@main
struct HemeraApp: App {

    @State private var authManager: AuthManager
    @State private var router: AppRouter
    @State private var environment: AppEnvironment
    @State private var sessionManager: SessionManager
    @State private var appCoordinator: AppCoordinator

    init() {
        Log.configure(subsystem: Bundle.main.bundleIdentifier ?? "com.hemera.app")
        #if DEBUG
        Log.addDestination(LogStore.shared)
        #endif
        let auth = AuthManager()
        let rtr = AppRouter(authManager: auth)
        let env = AppEnvironment()
        let sessionManager = SessionManager(authManager: auth, router: rtr, container: env.container, storage: env.storage)

        let demoCoordinator = DemoCoordinator()
        let appCoordinator = AppCoordinator(sessionManager: sessionManager, authManager: auth, router: rtr)
        demoCoordinator.delegate = appCoordinator

        ServiceLocator.configure(authManager: auth, router: rtr, demoCoordinator: demoCoordinator, sessionManager: sessionManager, screenManager: env.screenManager, areaDisplaySettings: env.areaDisplaySettings)
        ServiceLocator.shared.appCoordinator = appCoordinator

        // Start session for returning authenticated users — must be after ServiceLocator.configure()
        sessionManager.startIfAuthenticated()
        appCoordinator.startIfAuthenticated()

        #if DEBUG
        if CommandLine.arguments.contains("-screenshotMode") {
            demoCoordinator.enter()
        }
        #endif

        let screen = env.screenManager
        auth.addOnChangeHandler { state, _ in
            switch state {
            case .unauthenticated: screen.resetToDefaults()
            case .authenticated: break
            }
        }

        _authManager = State(initialValue: auth)
        _router = State(initialValue: rtr)
        _environment = State(initialValue: env)
        _sessionManager = State(initialValue: sessionManager)
        _appCoordinator = State(initialValue: appCoordinator)
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(router: router, authManager: authManager)
                .modelContainer(environment.container)
                .environment(environment.screenManager)
                .onChange(of: scenePhase) { _, newPhase in
                    Log.info("Scene phase: \(newPhase.label)")
                    environment.screenManager.handleScenePhase(newPhase)
                    sessionManager.handleScenePhase(newPhase)
                }
        }
    }
}

private extension ScenePhase {
    var label: String {
        switch self {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}
