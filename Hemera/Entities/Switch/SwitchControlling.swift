@MainActor
protocol SwitchControlling {
    func setSwitch(_ id: String, on: Bool) async
}
