import Foundation

@Observable
@MainActor
final class DemoModeBannerViewModel {
    var showExitDemoConfirmation = false

    private let demoCoordinator: any DemoCoordinating

    init(demoCoordinator: any DemoCoordinating) {
        self.demoCoordinator = demoCoordinator
    }

    convenience init() {
        self.init(demoCoordinator: ServiceLocator.shared.demoCoordinator)
    }

    func connect() {
        demoCoordinator.connectToServer()
    }

    func exitDemoTapped() {
        showExitDemoConfirmation = true
    }

    func confirmExitDemo() {
        demoCoordinator.exit()
    }
}
