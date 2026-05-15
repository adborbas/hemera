import SwiftData

extension DemoController: LightControlling {

    func setLight(_ id: String, on: Bool) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let light = LightEntity.fetch(byId: id, in: context) else { return }
        light.state = on ? .on : .off
        if on, light.brightness == nil {
            light.brightness = 255
        }
    }

    func setBrightness(_ id: String, to brightness: Int) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let light = LightEntity.fetch(byId: id, in: context) else { return }
        light.brightness = brightness
        light.state = brightness > 0 ? .on : .off
    }

    func setColorTemp(_ id: String, to mireds: Int) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let light = LightEntity.fetch(byId: id, in: context) else { return }
        light.colorTemp = mireds
        light.colorMode = "color_temp"
        light.state = .on
    }

    func setHSColor(_ id: String, hue: Double, saturation: Double) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let light = LightEntity.fetch(byId: id, in: context) else { return }
        light.hsColor = [hue, saturation]
        light.colorMode = "hs"
        light.state = .on
    }
}
