import Foundation
import HAKit
import Testing
@testable import Hemera

/**
 Tests that connection transitions are applied in delivery order so
 `onReconnect` fires exactly once per genuine reconnect and never spuriously.
 */
@MainActor
struct HAConnectionManagerTransitionTests {

    private func makeManager() -> HAConnectionManager {
        HAConnectionManager(serverURL: URL(string: "http://localhost:8123")!, tokenProvider: { "" })
    }

    @Test
    func firstConnect_doesNotFireReconnect() {
        let manager = makeManager()
        var reconnectCount = 0
        manager.onReconnect = { reconnectCount += 1 }

        manager.handleTransition(.connecting)
        manager.handleTransition(.authenticating)
        manager.handleTransition(.ready(version: "2024.1"))

        #expect(reconnectCount == 0)
        #expect(manager.isConnected)
    }

    @Test
    func reconnectAfterDrop_firesReconnectExactlyOnce() {
        let manager = makeManager()
        var reconnectCount = 0
        manager.onReconnect = { reconnectCount += 1 }

        // Initial connect — establishes `hasConnectedBefore`, no reconnect.
        manager.handleTransition(.ready(version: "2024.1"))
        #expect(reconnectCount == 0)

        // Drop, then recover — a genuine reconnect fires exactly once.
        manager.handleTransition(.disconnected(reason: .disconnected))
        #expect(!manager.isConnected)
        manager.handleTransition(.ready(version: "2024.1"))

        #expect(reconnectCount == 1)
        #expect(manager.isConnected)
    }

    @Test
    func repeatedReady_doesNotFireSpuriousReconnect() {
        let manager = makeManager()
        var reconnectCount = 0
        manager.onReconnect = { reconnectCount += 1 }

        /**
         Two `.ready` transitions with no intervening disconnect: the second
         is already-connected, so the reconnect check must not fire.
         */
        manager.handleTransition(.ready(version: "2024.1"))
        manager.handleTransition(.ready(version: "2024.1"))

        #expect(reconnectCount == 0)
        #expect(manager.isConnected)
    }
}
