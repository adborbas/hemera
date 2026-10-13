@MainActor
protocol ScriptControlling {
    func runScript(_ id: String) async
    func cancelScript(_ id: String) async
}
