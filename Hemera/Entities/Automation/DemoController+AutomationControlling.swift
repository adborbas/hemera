import Foundation
import SwiftData

extension DemoController: AutomationControlling {

    func setAutomation(_ id: String, on: Bool) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let entity = AutomationEntity.fetch(byId: id, in: context) else { return }
        entity.state = on ? .on : .off
    }

    func triggerAutomation(_ id: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let entity = AutomationEntity.fetch(byId: id, in: context) else { return }
        entity.lastTriggered = Date()
    }
}
