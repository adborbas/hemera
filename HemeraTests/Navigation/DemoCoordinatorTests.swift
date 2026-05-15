import Foundation
import Testing
@testable import Hemera

@MainActor
struct DemoCoordinatorTests {

    let coordinator: DemoCoordinator
    let delegate: MockDemoCoordinatorDelegate

    init() {
        coordinator = DemoCoordinator()
        delegate = MockDemoCoordinatorDelegate()
        coordinator.delegate = delegate
    }

    // MARK: - Enter

    @Test
    func enter_setsIsActiveToTrue() {
        coordinator.enter()

        #expect(coordinator.isActive == true)
    }

    @Test
    func enter_notifiesDelegate() {
        coordinator.enter()

        #expect(delegate.didEnterCallCount == 1)
    }

    // MARK: - Exit

    @Test
    func exit_setsIsActiveToFalse() {
        coordinator.enter()

        coordinator.exit()

        #expect(coordinator.isActive == false)
    }

    @Test
    func exit_notifiesDelegateWithConnectToServerFalse() {
        coordinator.enter()

        coordinator.exit()

        #expect(delegate.didExitCalls.count == 1)
        #expect(delegate.didExitCalls.first?.connectToServer == false)
    }

    // MARK: - Connect to Server

    @Test
    func connectToServer_setsIsActiveToFalse() {
        coordinator.enter()

        coordinator.connectToServer()

        #expect(coordinator.isActive == false)
    }

    @Test
    func connectToServer_notifiesDelegateWithConnectToServerTrue() {
        coordinator.enter()

        coordinator.connectToServer()

        #expect(delegate.didExitCalls.count == 1)
        #expect(delegate.didExitCalls.first?.connectToServer == true)
    }
}
