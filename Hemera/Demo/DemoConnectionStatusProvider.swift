import Foundation

/// Stub connection status for demo mode — always reports connected.
@MainActor
final class DemoConnectionStatusProvider: ConnectionStatusProviding {
    var isConnected: Bool { true }
}
