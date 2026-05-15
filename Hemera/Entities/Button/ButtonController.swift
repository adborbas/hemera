/// Production controller for button entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class ButtonController: ButtonControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func pressButton(_ id: String) async {
        await performServiceCall("Failed to press button \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.press, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "button"
    static let press = "press"
}
