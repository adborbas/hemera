@MainActor
protocol LightControlling {
    func setLight(_ id: String, on: Bool) async
    func setBrightness(_ id: String, to brightness: Int) async
    func setColorTemp(_ id: String, to mireds: Int) async
    func setHSColor(_ id: String, hue: Double, saturation: Double) async
}
