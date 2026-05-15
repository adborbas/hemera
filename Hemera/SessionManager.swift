import Foundation
import HemeraLog
import SwiftData
import SwiftUI

@MainActor
protocol ConnectionRetrying: AnyObject {
    func retryConnection()
}

/// Manages session lifecycle: HA connections, demo sessions, and teardown.
///
/// Pure wiring — creates session-scoped objects and registers them on ServiceLocator.
/// No presentation knowledge.
@MainActor
final class SessionManager: ConnectionRetrying {

    // Session-scoped (nil when not authenticated / no demo)
    private(set) var connectionManager: HAConnectionManager?
    private var syncService: HADataSyncService?
    private var demoContainer: ModelContainer?

    private var isResyncing = false
    private var wasBackgrounded = false

    private let authManager: any AuthManaging
    private weak var router: AppRouter?
    private let container: ModelContainer
    private let storage: Storage

    init(authManager: some AuthManaging, router: AppRouter, container: ModelContainer, storage: Storage) {
        self.authManager = authManager
        self.router = router
        self.container = container
        self.storage = storage

        // Register onChange handler (SessionManager registers FIRST for ordering guarantee)
        authManager.addOnChangeHandler { [weak self] state, _ in
            guard let self else { return }
            switch state {
            case .authenticated:
                self.startSession()
            case .unauthenticated:
                self.tearDownSession()
            }
        }

    }

    /// Call after ServiceLocator is configured to start the session for returning users.
    func startIfAuthenticated() {
        if authManager.state == .authenticated {
            Log.info("Resuming session for returning user")
            startSession()
        }
    }

    /// Re-attempts the WebSocket connection (e.g. after a timeout).
    func retryConnection() {
        Log.info("Retrying WebSocket connection")
        connectionManager?.disconnect()
        connectionManager?.connect()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            wasBackgrounded = true
        case .active:
            // Only resync after a true background trip. Brief `.inactive`
            // transitions (Notification Center, Control Center, incoming
            // calls) shouldn't trigger a full refetch.
            guard wasBackgrounded else { return }
            wasBackgrounded = false
            resyncIfNeeded()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    /// Starts a demo session with simulated data — no HA connection needed.
    ///
    /// Uses an in-memory `ModelContainer` so demo data never persists to disk.
    /// If the app is terminated during demo mode, no cleanup is needed on next launch.
    func startDemoSession() {
        Log.info("Starting demo session")

        let demoConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        let demoContainer = try! ModelContainer(for: AppEnvironment.createSchema(), configurations: demoConfig)
        self.demoContainer = demoContainer
        let demoContext = demoContainer.mainContext

        DemoDataProvider.seedDemoData(into: demoContext)
        let demoController = DemoController(context: demoContext)

        let factory = ViewModelFactory(context: demoContext, container: demoContainer)
        factory.registerAllDomains(
            lightController: demoController,
            coverController: demoController,
            sceneController: demoController,
            switchController: demoController,
            buttonController: demoController,
            automationController: demoController,
            climateController: demoController
        )
        let demoStorage = SwiftDataStorage(context: demoContext)
        let tileRepo = SwiftDataHomeTileRepository(storage: demoStorage)

        ServiceLocator.shared.session = Session(
            container: demoContainer,
            connectionStatusProvider: DemoConnectionStatusProvider(),
            homeTileRepository: tileRepo,
            viewModelFactory: factory,
            mainContext: demoContext,
            restClient: DemoRESTClient(),
            errorNotifier: ErrorNotifier(),
            resync: { }
        )
    }

    /// Tears down the demo session — the in-memory container is simply discarded.
    func tearDownDemoSession() {
        Log.info("Tearing down demo session")
        clearServiceLocator()
        demoContainer = nil
    }
}

// MARK: - Resync

private extension SessionManager {

    func resyncIfNeeded() {
        Task { await performResync() }
    }

    func performResync() async {
        guard syncService != nil, !isResyncing else { return }
        isResyncing = true
        defer { isResyncing = false }
        await syncService?.resync()
    }
}

// MARK: - Session Lifecycle

private extension SessionManager {

    func startSession() {
        guard let creds = authManager.credentials else { return }
        Log.info("Starting session for \(creds.serverURL.host() ?? "unknown")")

        let tokenProvider: @Sendable () async throws -> String = { [authManager] in
            try await authManager.validAccessToken()
        }

        let errorNotifier = ErrorNotifier()
        let connectionManager = HAConnectionManager(
            serverURL: creds.serverURL,
            tokenProvider: tokenProvider
        )
        let serviceCaller = HAServiceCaller(connection: connectionManager.connection)
        let restClient = HARESTClient(
            urlProvider: { creds.serverURL },
            tokenProvider: tokenProvider
        )

        let factory = ViewModelFactory(context: container.mainContext, container: container)
        factory.registerAllDomains(
            lightController: LightController(serviceCaller: serviceCaller, errorNotifier: errorNotifier),
            coverController: CoverController(serviceCaller: serviceCaller, errorNotifier: errorNotifier),
            sceneController: SceneController(serviceCaller: serviceCaller, errorNotifier: errorNotifier),
            switchController: SwitchController(serviceCaller: serviceCaller, errorNotifier: errorNotifier),
            buttonController: ButtonController(serviceCaller: serviceCaller, errorNotifier: errorNotifier),
            automationController: AutomationController(serviceCaller: serviceCaller, errorNotifier: errorNotifier),
            climateController: ClimateController(serviceCaller: serviceCaller, errorNotifier: errorNotifier)
        )
        let tileRepo = SwiftDataHomeTileRepository(storage: storage)

        let syncService = HADataSyncService(
            connectionManager: connectionManager,
            restClient: restClient,
            mainContext: container.mainContext,
            entityRegistry: .shared,
            errorNotifier: errorNotifier,
            onSyncComplete: { [weak self] in
                self?.isResyncing = false
                self?.router?.sessionReady()
            }
        )

        self.connectionManager = connectionManager
        self.syncService = syncService
        // Block scene-phase / reconnect resyncs from racing the initial sync.
        // Cleared by `onSyncComplete` above.
        isResyncing = true

        connectionManager.onReconnect = { [weak self] in
            self?.resyncIfNeeded()
        }

        ServiceLocator.shared.session = Session(
            container: container,
            connectionStatusProvider: connectionManager,
            homeTileRepository: tileRepo,
            viewModelFactory: factory,
            mainContext: container.mainContext,
            restClient: restClient,
            errorNotifier: errorNotifier,
            resync: { [weak self] in await self?.performResync() }
        )

        connectionManager.connect()
        syncService.start()
        Log.info("Session started — WebSocket connecting")
    }

    func tearDownSession() {
        Log.info("Tearing down session")
        connectionManager?.disconnect()
        connectionManager = nil
        syncService = nil
        isResyncing = false
        wasBackgrounded = false
        clearServiceLocator()
        wipeLocalData()
    }

    func clearServiceLocator() {
        ServiceLocator.shared.session = nil
    }

    func wipeLocalData() {
        let context = container.mainContext
        for entityType in EntityRegistry.shared.allEntityTypes {
            do {
                try context.delete(model: entityType)
            } catch {
                Log.error("Failed to delete \(entityType) during wipe", cause: error)
            }
        }
        do {
            try context.delete(model: AreaEntity.self)
        } catch {
            Log.error("Failed to delete areas during wipe", cause: error)
        }
        do {
            try context.delete(model: HomeTile.self)
        } catch {
            Log.error("Failed to delete home tiles during wipe", cause: error)
        }
        do {
            try context.save()
        } catch {
            Log.error("Failed to save after wiping local data", cause: error)
        }
    }
}
