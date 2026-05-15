/// Production controller for scene entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class SceneController: SceneControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func activateScene(_ id: String) async {
        await performServiceCall("Failed to activate scene \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.turnOn, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "scene"
    static let turnOn = "turn_on"
}
