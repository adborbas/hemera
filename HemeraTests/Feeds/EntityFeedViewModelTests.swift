import Foundation
import SwiftData
import Testing
import TileGridEngine
@testable import Hemera

@MainActor
struct EntityFeedViewModelTests {

    let container: ModelContainer
    let context: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: AppEnvironment.createSchema(), configurations: config)
        context = container.mainContext
    }

    // MARK: - Sections

    @Test func sections_followHomeAssistantAreaOrder() throws {
        // Matches how the user ordered their house in HA, not alphabetical or sync order.
        let kitchen = insertArea("kitchen", name: "Kitchen", sortOrder: 0)
        let attic = insertArea("attic", name: "Attic", sortOrder: 1)
        insertLight("light.attic", name: "Attic Lamp", area: attic)
        insertLight("light.kitchen", name: "Kitchen Lamp", area: kitchen)
        try context.save()

        #expect(makeLightsFeed().sections.map(\.title) == ["Kitchen", "Attic"])
    }

    @Test func sections_entitiesWithoutArea_areLastUnderOther() throws {
        // Unassigned lights must stay reachable without pushing real rooms down.
        let kitchen = insertArea("kitchen", name: "Kitchen", sortOrder: 5)
        insertLight("light.porch", name: "Porch", area: nil)
        insertLight("light.kitchen", name: "Kitchen Lamp", area: kitchen)
        try context.save()

        #expect(makeLightsFeed().sections.map(\.title) == ["Kitchen", "Other"])
    }

    @Test func sections_cardsWithinAnArea_areInNameOrder() throws {
        // Several "Lamp"s are only told apart by name, so names must read in order.
        let office = insertArea("office", name: "Office", sortOrder: 0)
        insertLight("light.a", name: "Lamp 10", area: office)
        insertLight("light.b", name: "Desk", area: office)
        insertLight("light.c", name: "Lamp 2", area: office)
        try context.save()

        #expect(makeLightsFeed().sections.first?.tiles.map(\.title) == ["Desk", "Lamp 2", "Lamp 10"])
    }

    @Test func sections_excludeEntitiesHiddenInHomeAssistant() throws {
        // Feeds must agree with area pages, which never show HA-hidden entities.
        let office = insertArea("office", name: "Office", sortOrder: 0)
        let hall = insertArea("hall", name: "Hall", sortOrder: 1)
        insertLight("light.desk", name: "Desk", area: office)
        insertLight("light.hidden", name: "Hidden", area: office).isHiddenInHA = true
        insertLight("light.hall", name: "Hall", area: hall).isHiddenInHA = true
        try context.save()

        let sections = makeLightsFeed().sections
        #expect(sections.map(\.title) == ["Office"])
        #expect(sections.first?.tiles.map(\.title) == ["Desk"])
    }

    @Test func sections_entityDeleted_dropsItsCard() throws {
        // A deleted entity's model is invalid after the save, so the grid must stop referencing it.
        let feed = makeLightsFeed()
        let light = insertLight("light.desk", name: "Desk", area: nil)
        insertLight("light.porch", name: "Porch", area: nil)
        try context.save()

        context.delete(light)
        try context.save()

        #expect(feed.sections.first?.tiles.map(\.title) == ["Porch"])
    }

    // MARK: - Helpers

    private func makeLightsFeed() -> EntityFeedViewModel {
        EntityFeedViewModel(
            LightEntity.self,
            summary: FeedSummary(title: "Lights", icon: "lightbulb"),
            tileSize: .small,
            context: context,
            viewModelFactory: ViewModelFactory(context: context, container: container),
            homeTileRepository: MockHomeTileRepository(),
            haWebViewPresenter: HAWebViewPresenter(authManager: MockAuthManager()),
            isDemoMode: false
        )
    }

    private func insertArea(_ id: String, name: String, sortOrder: Int) -> AreaEntity {
        let area = AreaEntity(areaId: id, name: name, sortOrder: sortOrder)
        context.insert(area)
        return area
    }

    @discardableResult
    private func insertLight(_ id: String, name: String, area: AreaEntity?) -> LightEntity {
        let light = LightEntity(entityId: id, name: name, state: .on)
        context.insert(light)
        light.area = area
        return light
    }
}
