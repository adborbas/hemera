import Foundation
import Synchronization

/**
 Holds the address the live session talks to, so the URL can change without
 rebuilding the session's object graph.

 `HAConnectionManager` and `HARESTClient` resolve the URL per request from a
 nonisolated context, so this cannot be `@MainActor` state read directly.
*/
final class ServerURLHolder: Sendable {

    private let storage: Mutex<URL>

    init(_ url: URL) {
        self.storage = Mutex(url)
    }

    var current: URL {
        storage.withLock { $0 }
    }

    func update(to url: URL) {
        storage.withLock { $0 = url }
    }
}
