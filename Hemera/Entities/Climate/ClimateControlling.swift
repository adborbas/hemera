@MainActor
protocol ClimateControlling {
    func setHVACMode(_ id: String, mode: String) async
    func setTemperature(_ id: String, temperature: Double) async
    func setTemperatureRange(_ id: String, low: Double, high: Double) async
    func setFanMode(_ id: String, mode: String) async
    func setSwingMode(_ id: String, mode: String) async
    func setPresetMode(_ id: String, mode: String) async
    func setHumidity(_ id: String, humidity: Double) async
    func turnOnClimate(_ id: String) async
    func turnOffClimate(_ id: String) async
}
