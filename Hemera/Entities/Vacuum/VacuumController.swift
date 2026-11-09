/// Production controller for vacuum entities, calling Home Assistant through `HAServiceCalling`.
@MainActor
final class VacuumController: VacuumControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func startVacuum(_ id: String) async {
        await performServiceCall("Failed to start vacuum \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.start, entityId: id)
        }
    }

    func pauseVacuum(_ id: String) async {
        await performServiceCall("Failed to pause vacuum \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.pause, entityId: id)
        }
    }

    func stopVacuum(_ id: String) async {
        await performServiceCall("Failed to stop vacuum \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.stop, entityId: id)
        }
    }

    func returnVacuumToBase(_ id: String) async {
        await performServiceCall("Failed to return vacuum \(id) to base") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.returnToBase, entityId: id)
        }
    }

    func locateVacuum(_ id: String) async {
        await performServiceCall("Failed to locate vacuum \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.locate, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "vacuum"
    static let start = "start"
    static let pause = "pause"
    static let stop = "stop"
    static let returnToBase = "return_to_base"
    static let locate = "locate"
}
