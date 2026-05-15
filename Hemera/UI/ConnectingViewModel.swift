import Foundation
import HemeraLog

@Observable
@MainActor
final class ConnectingViewModel {

    var timedOut = false
    var showSettings = false
    private(set) var timeoutTask: Task<Void, Never>?

    var serverHost: String {
        authManager.credentials?.serverURL.host() ?? "server"
    }

    private let authManager: any AuthManaging
    private let connectionRetrier: any ConnectionRetrying

    init(authManager: any AuthManaging, connectionRetrier: any ConnectionRetrying) {
        self.authManager = authManager
        self.connectionRetrier = connectionRetrier
    }

    convenience init() {
        let sl = ServiceLocator.shared
        self.init(authManager: sl.authManager, connectionRetrier: sl.sessionManager)
    }

    func startTimeout() {
        Log.info("Connection timeout started (15s)")
        timedOut = false
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            Log.warning("Connection timed out after 15s")
            timedOut = true
        }
    }

    func cancelTimeout() {
        timeoutTask?.cancel()
    }

    func retry() {
        Log.info("User retrying connection")
        connectionRetrier.retryConnection()
        startTimeout()
    }
}
