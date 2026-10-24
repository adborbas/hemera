import Foundation
@testable import Hemera

/**
 Answers per-scheme so resolution order can be asserted, and records what was asked.

 Defaults to answering everything, so tests that don't care about resolution never reach
 the network.
*/
final class MockServerProbe: ServerProbing, @unchecked Sendable {

    /// Schemes that answer as Home Assistant. `nil` means every scheme answers.
    private let answering: Set<String>?
    private let otherwise: any Error

    private let lock = NSLock()
    private var _probed: [(url: URL, timeout: TimeInterval)] = []

    var probed: [(url: URL, timeout: TimeInterval)] {
        lock.lock(); defer { lock.unlock() }
        return _probed
    }

    init(answering: Set<String>? = nil, otherwise: any Error = AuthError.serverUnreachable) {
        self.answering = answering
        self.otherwise = otherwise
    }

    /// Nothing answers — every candidate fails with `error`.
    static func failing(_ error: any Error) -> MockServerProbe {
        MockServerProbe(answering: [], otherwise: error)
    }

    func probe(_ serverURL: URL, timeout: TimeInterval) async throws {
        lock.lock()
        _probed.append((serverURL, timeout))
        lock.unlock()

        guard let answering else { return }
        guard answering.contains(serverURL.scheme ?? "") else { throw otherwise }
    }
}
