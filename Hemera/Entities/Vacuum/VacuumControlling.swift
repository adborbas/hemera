@MainActor
protocol VacuumControlling {
    func startVacuum(_ id: String) async
    func pauseVacuum(_ id: String) async
    func stopVacuum(_ id: String) async
    func returnVacuumToBase(_ id: String) async
    func locateVacuum(_ id: String) async
}
