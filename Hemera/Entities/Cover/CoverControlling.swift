@MainActor
protocol CoverControlling {
    func setPosition(of id: String, to position: Int) async
    func openCover(_ id: String) async
    func closeCover(_ id: String) async
    func stopCover(_ id: String) async
    func toggleCover(_ id: String) async
}
