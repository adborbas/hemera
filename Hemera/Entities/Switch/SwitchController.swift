/// Production controller for switch entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class SwitchController: SwitchControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func setSwitch(_ id: String, on: Bool) async {
        await performServiceCall("Failed to set switch \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: on ? Keys.turnOn : Keys.turnOff,
                entityId: id
            )
        }
    }
}

private enum Keys {
    static let domain = "switch"
    static let turnOn = "turn_on"
    static let turnOff = "turn_off"
}
