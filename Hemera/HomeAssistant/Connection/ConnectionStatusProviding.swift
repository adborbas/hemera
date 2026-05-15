import Foundation

/// Provides read-only access to the current connection status.
@MainActor
protocol ConnectionStatusProviding: AnyObject {
    var isConnected: Bool { get }
}

extension HAConnectionManager: ConnectionStatusProviding {}
