import Foundation

@MainActor
protocol DemoCoordinatorDelegate: AnyObject {
    func demoDidEnter()
    func demoDidExit()
}

@MainActor
protocol DemoCoordinating: AnyObject {
    var isActive: Bool { get }
    func enter()
    func exit()
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
        delegate?.demoDidExit()
    }
}
