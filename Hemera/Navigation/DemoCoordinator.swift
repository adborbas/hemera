import Foundation

@MainActor
protocol DemoCoordinatorDelegate: AnyObject {
    func demoDidEnter()
    func demoDidExit(connectToServer: Bool)
}

@MainActor
protocol DemoCoordinating: AnyObject {
    var isActive: Bool { get }
    func enter()
    func exit()
    func connectToServer()
}

@MainActor
final class DemoCoordinator: DemoCoordinating {
    private(set) var isActive = false
    weak var delegate: DemoCoordinatorDelegate?

    func enter() {
        isActive = true
        delegate?.demoDidEnter()
    }

    func exit() {
        isActive = false
        delegate?.demoDidExit(connectToServer: false)
    }

    func connectToServer() {
        isActive = false
        delegate?.demoDidExit(connectToServer: true)
    }
}
