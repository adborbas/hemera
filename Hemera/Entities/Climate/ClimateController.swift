/// Production controller for climate entities.
///
/// Delegates to `HAServiceCalling` for WebSocket communication
/// with the Home Assistant server.
@MainActor
final class ClimateController: ClimateControlling, ServiceCallErrorHandling {
    private let serviceCaller: HAServiceCalling
    let errorNotifier: ErrorNotifier

    init(serviceCaller: HAServiceCalling, errorNotifier: ErrorNotifier) {
        self.serviceCaller = serviceCaller
        self.errorNotifier = errorNotifier
    }

    func setHVACMode(_ id: String, mode: String) async {
        await performServiceCall("Failed to set HVAC mode for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setHVACMode,
                entityId: id,
                extraData: [Keys.hvacMode: mode]
            )
        }
    }

    func setTemperature(_ id: String, temperature: Double) async {
        await performServiceCall("Failed to set temperature for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setTemperature,
                entityId: id,
                extraData: [Keys.temperature: temperature]
            )
        }
    }

    func setTemperatureRange(_ id: String, low: Double, high: Double) async {
        await performServiceCall("Failed to set temperature range for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setTemperature,
                entityId: id,
                extraData: [Keys.targetTempLow: low, Keys.targetTempHigh: high]
            )
        }
    }

    func setFanMode(_ id: String, mode: String) async {
        await performServiceCall("Failed to set fan mode for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setFanMode,
                entityId: id,
                extraData: [Keys.fanMode: mode]
            )
        }
    }

    func setSwingMode(_ id: String, mode: String) async {
        await performServiceCall("Failed to set swing mode for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setSwingMode,
                entityId: id,
                extraData: [Keys.swingMode: mode]
            )
        }
    }

    func setPresetMode(_ id: String, mode: String) async {
        await performServiceCall("Failed to set preset mode for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setPresetMode,
                entityId: id,
                extraData: [Keys.presetMode: mode]
            )
        }
    }

    func setHumidity(_ id: String, humidity: Double) async {
        await performServiceCall("Failed to set humidity for \(id)") {
            try await serviceCaller.callService(
                domain: Keys.domain,
                service: Keys.setHumidity,
                entityId: id,
                extraData: [Keys.humidity: humidity]
            )
        }
    }

    func turnOnClimate(_ id: String) async {
        await performServiceCall("Failed to turn on climate \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.turnOn, entityId: id)
        }
    }

    func turnOffClimate(_ id: String) async {
        await performServiceCall("Failed to turn off climate \(id)") {
            try await serviceCaller.callService(domain: Keys.domain, service: Keys.turnOff, entityId: id)
        }
    }
}

private enum Keys {
    static let domain = "climate"
    static let setHVACMode = "set_hvac_mode"
    static let setTemperature = "set_temperature"
    static let setFanMode = "set_fan_mode"
    static let setSwingMode = "set_swing_mode"
    static let setPresetMode = "set_preset_mode"
    static let setHumidity = "set_humidity"
    static let turnOn = "turn_on"
    static let turnOff = "turn_off"
    static let hvacMode = "hvac_mode"
    static let temperature = "temperature"
    static let targetTempLow = "target_temp_low"
    static let targetTempHigh = "target_temp_high"
    static let fanMode = "fan_mode"
    static let swingMode = "swing_mode"
    static let presetMode = "preset_mode"
    static let humidity = "humidity"
}
