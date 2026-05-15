import Foundation
@testable import Hemera

@MainActor
final class MockDemoCoordinatorDelegate: DemoCoordinatorDelegate {
    var didEnterCallCount = 0
    var didExitCalls: [(connectToServer: Bool, Void)] = []

    func demoDidEnter() {
        didEnterCallCount += 1
    }

    func demoDidExit(connectToServer: Bool) {
        didExitCalls.append((connectToServer, ()))
    }
}
