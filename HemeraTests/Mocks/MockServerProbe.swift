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
    /// Holds each probe open until `release()`, so a test can act while an attempt is in flight.
    private let blocks: Bool

    private let lock = NSLock()
    private var _probed: [(url: URL, timeout: TimeInterval)] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var released = false

    var probed: [(url: URL, timeout: TimeInterval)] {
        lock.lock(); defer { lock.unlock() }
        return _probed
    }

    init(
        answering: Set<String>? = nil,
        otherwise: any Error = AuthError.serverUnreachable,
        blocks: Bool = false
    ) {
        self.answering = answering
        self.otherwise = otherwise
        self.blocks = blocks
    }

    /// Nothing answers — every candidate fails with `error`.
    static func failing(_ error: any Error) -> MockServerProbe {
        MockServerProbe(answering: [], otherwise: error)
    }

    /// Lets a blocked probe finish. Safe to call before the probe reaches the gate.
    func release() {
        lock.lock()
        released = true
        let waiting = gate
        gate = nil
        lock.unlock()
        waiting?.resume()
    }

    func probe(_ serverURL: URL, timeout: TimeInterval) async throws {
        lock.lock()
        _probed.append((serverURL, timeout))
        lock.unlock()

        if blocks {
            await withCheckedContinuation { continuation in
                lock.lock()
                if released {
                    lock.unlock()
                    continuation.resume()
                } else {
                    gate = continuation
                    lock.unlock()
                }
            }
        }

        guard let answering else { return }
        guard answering.contains(serverURL.scheme ?? "") else { throw otherwise }
    }
}
