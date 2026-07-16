import Foundation
import HAKit
import HemeraLog

/// Manages the WebSocket connection to Home Assistant using HAKit.
@Observable
@MainActor
final class HAConnectionManager {

    let connection: HAConnection

    private(set) var isConnected = false
    private(set) var lastError: Error?

    /// Called when the connection recovers after a previous successful connection.
    var onReconnect: (() -> Void)?

    private var hasConnectedBefore = false

    init(serverURL: URL, tokenProvider: @escaping @Sendable () async throws -> String) {
        let haConfig = HAConnectionConfiguration(
            connectionInfo: {
                // HAKit will append /api/websocket automatically
                try? HAConnectionInfo(url: serverURL)
            },
            fetchAuthToken: { completion in
                Task {
                    do {
                        let token = try await tokenProvider()
                        completion(.success(token))
                    } catch {
                        Log.error("Token fetch failed during WebSocket auth", cause: error)
                        completion(.failure(error))
                    }
                }
            }
        )

        connection = HAKit.connection(configuration: haConfig)
        connection.delegate = self
        connection.callbackQueue = .main
    }

    func connect() {
        connection.connect()
        Log.info("Connecting to Home Assistant...")
    }

    func disconnect() {
        Log.info("Disconnecting from Home Assistant")
        // `onReconnect` is intentionally retained so that flows which
        // disconnect+reconnect (e.g. `SessionManager.retryConnection()`)
        // still trigger a resync once the connection re-establishes.
        // Session teardown drops the whole `HAConnectionManager`, so the
        // closure is released along with it.
        connection.disconnect()
    }
}

// MARK: - HAConnectionDelegate

extension HAConnectionManager: HAConnectionDelegate {
    nonisolated func connection(_ connection: HAConnection, didTransitionTo state: HAConnectionState) {
        /**
         HAKit delivers this callback synchronously on `.main`
         (`connection.callbackQueue = .main`, set in `init`), so handle each
         transition in delivery order. Wrapping every transition in its own
         unstructured `Task` would drop that ordering guarantee, so a
         `.disconnected` then `.ready` pair could compute the reconnect check
         against stale state and miss or spuriously fire `onReconnect`.
         */
        MainActor.assumeIsolated {
            handleTransition(state)
        }
    }

    func handleTransition(_ state: HAConnectionState) {
        let wasConnected = isConnected
        switch state {
        case .ready:
            isConnected = true
            lastError = nil
            Log.info("Connected to Home Assistant")

            if !wasConnected && hasConnectedBefore {
                Log.info("Reconnected to Home Assistant — triggering resync")
                onReconnect?()
            }
            hasConnectedBefore = true
        case .disconnected:
            isConnected = false
            Log.warning("Connection state: disconnected")
        case .connecting:
            isConnected = false
            Log.info("Connection state: connecting")
        case .authenticating:
            isConnected = false
            Log.info("Connection state: authenticating")
        }
    }
}

// MARK: - Async Helpers for HAConnection

extension HAConnection {
    /// Async wrapper for typed requests.
    func send<Response>(_ request: HATypedRequest<Response>) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            self.send(request) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Async wrapper for raw HARequest.
    func send(_ request: HARequest) async throws -> HAData {
        try await withCheckedThrowingContinuation { continuation in
            self.send(request) { result in
                continuation.resume(with: result)
            }
        }
    }

}
