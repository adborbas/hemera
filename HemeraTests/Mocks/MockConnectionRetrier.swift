import Foundation
@testable import Hemera

@MainActor
final class MockConnectionRetrier: ConnectionRetrying {
    var retryCallCount = 0

    func retryConnection() {
        retryCallCount += 1
    }
}
