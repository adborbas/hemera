/// Production controller for light entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class LightController: LightControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func setLight(_ id: String, on: Bool) async {
        await performServiceCall("Failed to set light \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: on ? Keys.turnOn : Keys.turnOff,
                entityId: id
            )
        }
    }

    func setBrightness(_ id: String, to brightness: Int) async {
        await performServiceCall("Failed to set brightness for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.turnOn,
                entityId: id,
                extraData: [Keys.brightness: brightness]
            )
        }
    }

    func setColorTemp(_ id: String, to mireds: Int) async {
        await performServiceCall("Failed to set color temp for \(id)") {
            let kelvin = mireds > 0 ? 1_000_000 / mireds : 0
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.turnOn,
                entityId: id,
                extraData: [Keys.colorTempKelvin: kelvin]
            )
        }
    }

    func setHSColor(_ id: String, hue: Double, saturation: Double) async {
        await performServiceCall("Failed to set HS color for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.turnOn,
                entityId: id,
                extraData: [Keys.hsColor: [hue, saturation]]
            )
        }
    }
}

private enum Keys {
    static let domain = "light"
    static let turnOn = "turn_on"
    static let turnOff = "turn_off"
    static let brightness = "brightness"
    static let colorTempKelvin = "color_temp_kelvin"
    static let hsColor = "hs_color"
}
