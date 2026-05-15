/// Production controller for automation entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class AutomationController: AutomationControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func setAutomation(_ id: String, on: Bool) async {
        await performServiceCall("Failed to set automation \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: on ? Keys.turnOn : Keys.turnOff,
                entityId: id
            )
        }
    }

    func triggerAutomation(_ id: String) async {
        await performServiceCall("Failed to trigger automation \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.trigger, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "automation"
    static let turnOn = "turn_on"
    static let turnOff = "turn_off"
    static let trigger = "trigger"
}
