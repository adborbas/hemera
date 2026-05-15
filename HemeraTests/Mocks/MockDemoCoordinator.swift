import Foundation
@testable import Hemera

@MainActor
final class MockDemoCoordinator: DemoCoordinating {
    private(set) var isActive = false
    var enterCallCount = 0
    var exitCallCount = 0
    var connectToServerCallCount = 0

    func enter() {
        isActive = true
        enterCallCount += 1
    }

    func exit() {
        isActive = false
        exitCallCount += 1
    }

    func connectToServer() {
        isActive = false
        connectToServerCallCount += 1
    }
}
