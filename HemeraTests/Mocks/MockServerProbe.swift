import Foundation
@testable import Hemera

/// Succeeds unless given an error to throw, so tests never reach the network.
final class MockServerProbe: ServerProbing, @unchecked Sendable {

    private let error: (any Error)?

    init(throwing error: (any Error)? = nil) {
        self.error = error
    }

    func probe(_ serverURL: URL) async throws {
        if let error {
            throw error
        }
    }
}
