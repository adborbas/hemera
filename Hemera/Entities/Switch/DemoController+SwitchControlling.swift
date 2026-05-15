import SwiftData

extension DemoController: SwitchControlling {

    func setSwitch(_ id: String, on: Bool) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let entity = SwitchEntity.fetch(byId: id, in: context) else { return }
        entity.state = on ? .on : .off
    }
}
