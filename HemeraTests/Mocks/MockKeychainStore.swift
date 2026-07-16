import Foundation
import Synchronization
@testable import Hemera

/// Error surfaced by `MockKeychainStore` when configured to simulate a Keychain failure.
struct MockKeychainError: Error {}

/**
 Hand-written spy/stub for `KeychainStoring`. Tracks call counts and can be
 configured to throw from `saveCredentials`/`clearAll` to exercise failure paths.
 State is guarded by a `Mutex` so the type is genuinely `Sendable`.
 */
final class MockKeychainStore: KeychainStoring {

    private struct State {
        var saveCredentialsCallCount = 0
        var clearAllCallCount = 0
        var savedCredentials: ServerCredentials?
        var storedCredentials: ServerCredentials?
        var saveError: Error?
        var clearError: Error?
    }

    private let state: Mutex<State>

    init(storedCredentials: ServerCredentials? = nil, saveError: Error? = nil, clearError: Error? = nil) {
        var initial = State()
        initial.storedCredentials = storedCredentials
        initial.saveError = saveError
        initial.clearError = clearError
        self.state = Mutex(initial)
    }

    var saveCredentialsCallCount: Int { state.withLock { $0.saveCredentialsCallCount } }
    var clearAllCallCount: Int { state.withLock { $0.clearAllCallCount } }
    var savedCredentials: ServerCredentials? { state.withLock { $0.savedCredentials } }

    func saveCredentials(_ credentials: ServerCredentials) throws {
        try state.withLock {
            $0.saveCredentialsCallCount += 1
            if let error = $0.saveError { throw error }
            $0.savedCredentials = credentials
            $0.storedCredentials = credentials
        }
    }

    func loadCredentials() -> ServerCredentials? {
        state.withLock { $0.storedCredentials }
    }

    func clearAll() throws {
        try state.withLock {
            $0.clearAllCallCount += 1
            if let error = $0.clearError { throw error }
            $0.storedCredentials = nil
        }
    }
}
