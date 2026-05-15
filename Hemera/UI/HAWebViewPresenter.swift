import Foundation

@Observable
@MainActor
final class HAWebViewPresenter {

    var isPresented = false
    private(set) var url: URL?

    private let authManager: any AuthManaging
    private(set) var presentationTask: Task<Void, Never>?

    init(authManager: any AuthManaging) {
        self.authManager = authManager
    }

    func openArea(_ areaId: String) {
        guard let base = authManager.credentials?.serverURL else { return }
        present(base.appendingPathComponent("config/areas/area/\(areaId)"))
    }

    func openEntity(_ entityId: String, deviceId: String?) {
        guard let base = authManager.credentials?.serverURL else { return }
        if let deviceId {
            present(base.appendingPathComponent("config/devices/device/\(deviceId)"))
        } else {
            present(base.appendingPathComponent("config/entities/entity/\(entityId)"))
        }
    }

    /// Defers presentation so a context menu dismiss animation can complete first.
    private func present(_ targetURL: URL) {
        presentationTask?.cancel()
        url = targetURL
        presentationTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isPresented = true
        }
    }

    func dismiss() {
        presentationTask?.cancel()
        presentationTask = nil
        isPresented = false
        url = nil
    }

    func validAccessToken() async throws -> String {
        try await authManager.validAccessToken()
    }
}
