/**
 Production controller for script entities.

 Delegates to `HAServiceCalling` for WebSocket communication
 with the Home Assistant server.
*/
@MainActor
final class ScriptController: ScriptControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func runScript(_ id: String) async {
        await performServiceCall("Failed to run script \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.turnOn, entityId: id)
        }
    }

    func cancelScript(_ id: String) async {
        await performServiceCall("Failed to cancel script \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.turnOff, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "script"
    static let turnOn = "turn_on"
    static let turnOff = "turn_off"
}
