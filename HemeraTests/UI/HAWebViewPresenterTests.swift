import Foundation
import Testing
@testable import Hemera

@MainActor
struct HAWebViewPresenterTests {

    let authManager: MockAuthManager
    let presenter: HAWebViewPresenter

    init() {
        authManager = MockAuthManager()
        authManager.credentials = ServerCredentials(
            serverURL: URL(string: "http://192.168.1.100:8123")!,
            accessToken: "test",
            refreshToken: "test",
            tokenExpiresAt: .distantFuture,
            clientId: "test"
        )
        presenter = HAWebViewPresenter(authManager: authManager)
    }

    // MARK: - openArea

    @Test
    func openArea_setsURLAndPresents() async {
        presenter.openArea("living_room")

        #expect(presenter.url?.path.contains("config/areas/area/living_room") == true)
        await presenter.presentationTask?.value
        #expect(presenter.isPresented == true)
    }

    // MARK: - openEntity

    @Test
    func openEntity_withDeviceId_opensDevicePage() async {
        presenter.openEntity("light.living_room", deviceId: "abc123")

        #expect(presenter.url?.path.contains("config/devices/device/abc123") == true)
        await presenter.presentationTask?.value
        #expect(presenter.isPresented == true)
    }

    @Test
    func openEntity_withoutDeviceId_opensEntityPage() async {
        presenter.openEntity("light.living_room", deviceId: nil)

        #expect(presenter.url?.path.contains("config/entities/entity/light.living_room") == true)
        await presenter.presentationTask?.value
        #expect(presenter.isPresented == true)
    }

    // MARK: - dismiss

    @Test
    func dismiss_clearsState() async {
        presenter.openArea("living_room")
        await presenter.presentationTask?.value

        presenter.dismiss()

        #expect(presenter.isPresented == false)
        #expect(presenter.url == nil)
    }

    // MARK: - No credentials

    @Test
    func openArea_withoutCredentials_doesNotPresent() {
        authManager.credentials = nil

        presenter.openArea("living_room")

        #expect(presenter.isPresented == false)
        #expect(presenter.url == nil)
    }

    @Test
    func openEntity_withoutCredentials_doesNotPresent() {
        authManager.credentials = nil

        presenter.openEntity("light.living_room", deviceId: nil)

        #expect(presenter.isPresented == false)
        #expect(presenter.url == nil)
    }
}
