import SwiftData

extension DemoController: ClimateControlling {

    func setHVACMode(_ id: String, mode: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.state = ClimateEntity.HVACMode(rawValue: mode) ?? .unknown
        switch climate.state {
        case .heat: climate.hvacAction = .heating
        case .cool: climate.hvacAction = .cooling
        case .dry: climate.hvacAction = .drying
        case .fanOnly: climate.hvacAction = .fan
        case .off: climate.hvacAction = .off
        case .heatCool, .auto: climate.hvacAction = .idle
        default: climate.hvacAction = nil
        }
    }

    func setTemperature(_ id: String, temperature: Double) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.temperature = temperature
    }

    func setTemperatureRange(_ id: String, low: Double, high: Double) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.targetTempLow = low
        climate.targetTempHigh = high
    }

    func setFanMode(_ id: String, mode: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.fanMode = mode
    }

    func setSwingMode(_ id: String, mode: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.swingMode = mode
    }

    func setPresetMode(_ id: String, mode: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.presetMode = mode
    }

    func setHumidity(_ id: String, humidity: Double) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.humidity = humidity
    }

    func turnOnClimate(_ id: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        if let firstNonOff = climate.hvacModesRaw.first(where: { $0 != "off" }),
           let mode = ClimateEntity.HVACMode(rawValue: firstNonOff) {
            climate.state = mode
        } else {
            climate.state = .heat
        }
        switch climate.state {
        case .heat: climate.hvacAction = .heating
        case .cool: climate.hvacAction = .cooling
        case .dry: climate.hvacAction = .drying
        case .fanOnly: climate.hvacAction = .fan
        case .heatCool, .auto: climate.hvacAction = .idle
        default: climate.hvacAction = nil
        }
    }

    func turnOffClimate(_ id: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let climate = ClimateEntity.fetch(byId: id, in: context) else { return }
        climate.state = .off
        climate.hvacAction = .off
    }
}
