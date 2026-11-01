import Foundation
@testable import Hemera

/// Blocks one range's request until released, so a test can read the model mid-fetch.
final class GatedHistoryProvider: SensorHistoryProviding, @unchecked Sendable {

    struct Request { let entityId: String; let range: TimeRange }

    var requests: [Request] {
        withLock { _requests }
    }

    private let lock = NSLock()
    private var _requests: [Request] = []
    private var gate: CheckedContinuation<Void, Never>?
    private var released = false
    private let gatedRange: TimeRange
    private let results: [TimeRange: [ClimateSample]]

    init(gatedRange: TimeRange, results: [TimeRange: [ClimateSample]]) {
        self.gatedRange = gatedRange
        self.results = results
    }

    /// Locking stays in synchronous helpers, away from the async path.
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func register(_ continuation: CheckedContinuation<Void, Never>) {
        withLock {
            if released {
                continuation.resume()
            } else {
                gate = continuation
            }
        }
    }

    private func awaitGate() async {
        await withCheckedContinuation { continuation in
            register(continuation)
        }
    }

    /// Lets a blocked request finish, so a test can act while it was in flight.
    func release() {
        withLock {
            released = true
            gate?.resume()
            gate = nil
        }
    }

    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        withLock { _requests.append(Request(entityId: entityId, range: range)) }
        if range == gatedRange {
            await awaitGate()
        }
        return results[range] ?? []
    }
}
