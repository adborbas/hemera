/// Production controller for cover entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class CoverController: CoverControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func setPosition(of id: String, to position: Int) async {
        await performServiceCall("Failed to set position for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setPosition,
                entityId: id,
                extraData: [Keys.position: position]
            )
        }
    }

    func openCover(_ id: String) async {
        await performServiceCall("Failed to open cover \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.open, entityId: id)
        }
    }

    func closeCover(_ id: String) async {
        await performServiceCall("Failed to close cover \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.close, entityId: id)
        }
    }

    func stopCover(_ id: String) async {
        await performServiceCall("Failed to stop cover \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.stop, entityId: id)
        }
    }

    func toggleCover(_ id: String) async {
        await performServiceCall("Failed to toggle cover \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.toggle, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "cover"
    static let setPosition = "set_cover_position"
    static let open = "open_cover"
    static let close = "close_cover"
    static let stop = "stop_cover"
    static let toggle = "toggle"
    static let position = "position"
}
