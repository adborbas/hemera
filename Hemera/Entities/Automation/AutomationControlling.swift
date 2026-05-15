@MainActor
protocol AutomationControlling {
    func setAutomation(_ id: String, on: Bool) async
    func triggerAutomation(_ id: String) async
}
