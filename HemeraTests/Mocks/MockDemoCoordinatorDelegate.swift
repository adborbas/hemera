import Foundation
@testable import Hemera

@MainActor
final class MockDemoCoordinatorDelegate: DemoCoordinatorDelegate {
    var didEnterCallCount = 0
    var didExitCallCount = 0

    func demoDidEnter() {
        didEnterCallCount += 1
    }

    func demoDidExit() {
        didExitCallCount += 1
    }
}
