import Foundation
import Testing
@testable import Hemera

@MainActor
struct DemoModeBannerViewModelTests {

    let viewModel: DemoModeBannerViewModel
    let coordinator: MockDemoCoordinator

    init() {
        coordinator = MockDemoCoordinator()
        coordinator.enter()
        viewModel = DemoModeBannerViewModel(demoCoordinator: coordinator)
    }

    // MARK: - Connect

    @Test
    func connect_deactivatesDemoCoordinator() {
        viewModel.connect()

        #expect(coordinator.isActive == false)
        #expect(coordinator.connectToServerCallCount == 1)
    }

    // MARK: - Exit Demo

    @Test
    func exitDemoTapped_setsShowExitDemoConfirmationToTrue() {
        viewModel.exitDemoTapped()

        #expect(viewModel.showExitDemoConfirmation == true)
    }

    @Test
    func confirmExitDemo_deactivatesDemoCoordinator() {
        viewModel.confirmExitDemo()

        #expect(coordinator.isActive == false)
        #expect(coordinator.exitCallCount == 1)
    }
}
