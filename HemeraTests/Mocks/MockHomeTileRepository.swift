import Foundation
import TileGridEngine
@testable import Hemera

@MainActor
final class MockHomeTileRepository: HomeTileRepository {
    var stubbedHasAnyHomeTile = false
    var stubbedOnHome: Set<String> = []

    private(set) var addToHomeCalls: [String] = []
    private(set) var removeFromHomeCalls: [String] = []
    private(set) var commitLayoutCalls: [[(entityId: String, sortOrder: Int, size: TileSize)]] = []

    func hasAnyHomeTile() -> Bool {
        stubbedHasAnyHomeTile
    }

    func isOnHome(entityId: String) -> Bool {
        stubbedOnHome.contains(entityId)
    }

    func addToHome(entityId: String) {
        addToHomeCalls.append(entityId)
        stubbedOnHome.insert(entityId)
    }

    func removeFromHome(entityId: String) {
        removeFromHomeCalls.append(entityId)
        stubbedOnHome.remove(entityId)
    }

    func commitHomeTileLayout(_ updates: [(entityId: String, sortOrder: Int, size: TileSize)]) {
        commitLayoutCalls.append(updates)
    }
}
