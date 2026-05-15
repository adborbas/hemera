import Foundation
import Synchronization

/// In-memory ring buffer for log entries, accessible from the debug panel.
///
/// Thread-safe via `Mutex`. Conforms to `LogDestination` so it can be
/// registered with `Log.addDestination()`.
public final class LogStore: LogDestination, Sendable {

    public static let shared = LogStore()

    private let buffer = Mutex<[LogEntry]>([])
    private let capacity: Int

    public init(capacity: Int = 500) {
        self.capacity = capacity
    }

    public func receive(_ entry: LogEntry) {
        buffer.withLock { entries in
            entries.append(entry)
            if entries.count > capacity {
                entries.removeFirst(entries.count - capacity)
            }
        }
    }

    /// Returns a snapshot of all stored entries.
    public var entries: [LogEntry] {
        buffer.withLock { Array($0) }
    }

    /// Removes all stored entries.
    public func clear() {
        buffer.withLock { $0.removeAll() }
    }
}
