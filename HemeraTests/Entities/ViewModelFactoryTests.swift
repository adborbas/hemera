import Foundation
import SwiftData
import Testing
@testable import Hemera

@MainActor
struct ViewModelFactoryTests {

    // MARK: - Cache Eviction

    @Test
    func makeViewModel_afterBackingModelDeleted_returnsNil() throws {
        let (factory, context) = makeFactory()
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on)
        context.insert(light)
        try context.save()

        // Cache a VM for the entity.
        let cached = factory.makeViewModel(forEntityId: "light.test")
        #expect(cached != nil)

        // Delete the backing model mid-session, then look up again.
        context.delete(light)
        try context.save()

        #expect(factory.makeViewModel(forEntityId: "light.test") == nil)
    }

    @Test
    func makeViewModel_forLiveEntity_returnsSameCachedInstance() throws {
        let (factory, context) = makeFactory()
        let light = LightEntity(entityId: "light.test", name: "Test", state: .on)
        context.insert(light)
        try context.save()

        let first = factory.makeViewModel(forEntityId: "light.test")
        let second = factory.makeViewModel(forEntityId: "light.test")

        #expect(first != nil)
        #expect((first as AnyObject) === (second as AnyObject))
    }

    // MARK: - Helpers

    private func makeFactory() -> (ViewModelFactory, ModelContext) {
        let schema = Schema([LightEntity.self, AreaEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = container.mainContext
        let factory = ViewModelFactory(context: context, container: container)
        factory.register(LightCardViewModel.registration(controller: StubLightControlling()))
        return (factory, context)
    }
}

@MainActor
private final class StubLightControlling: LightControlling {
    func setLight(_ id: String, on: Bool) async {}
    func setBrightness(_ id: String, to brightness: Int) async {}
    func setColorTemp(_ id: String, to mireds: Int) async {}
    func setHSColor(_ id: String, hue: Double, saturation: Double) async {}
}
