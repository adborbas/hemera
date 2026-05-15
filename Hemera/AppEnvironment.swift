import Foundation
import HemeraLog
import SwiftData

/// App-lifetime dependency container: SwiftData, entity registry, storage.
///
/// Session lifecycle (HA connections, demo sessions) lives in `SessionManager`.
@MainActor
final class AppEnvironment {

    let container: ModelContainer
    let storage: Storage
    let screenManager: ScreenManager

    init() {
        Self.registerEntities()
        let schema = Self.createSchema()
        let modelConfig = ModelConfiguration(isStoredInMemoryOnly: false)

        // Migration strategy: SwiftData handles additive schema changes (new properties
        // with defaults, new models) via lightweight migration automatically. If a breaking
        // schema change causes ModelContainer creation to fail, we delete the store and
        // re-sync from the server. The only data lost is HomeTile layout (user-curated
        // home screen tiles). When HomeTile data becomes more valuable (e.g., with complex
        // user customizations), introduce VersionedSchema + SchemaMigrationPlan.
        do {
            self.container = try ModelContainer(for: schema, configurations: modelConfig)
        } catch {
            Log.error("ModelContainer creation failed — deleting store (HomeTile layout will be lost). Error: \(error)")
            Self.deleteStore(at: modelConfig.url)
            self.container = try! ModelContainer(for: schema, configurations: modelConfig)
        }

        self.storage = SwiftDataStorage(context: container.mainContext)
        self.screenManager = ScreenManager()
    }
}

// MARK: - Schema

extension AppEnvironment {
    static func createSchema() -> Schema {
        Schema(EntityRegistry.shared.allEntityTypes + [AreaEntity.self, HomeTile.self])
    }
}

// MARK: - Entity Configuration

private extension AppEnvironment {

    static func registerEntities() {
        let registry = EntityRegistry.shared
        registry.register(LightEntity.self)
        registry.register(CoverEntity.self)
        registry.register(SceneEntity.self)
        registry.register(SensorEntity.self)
        registry.register(BinarySensorEntity.self)
        registry.register(SwitchEntity.self)
        registry.register(ButtonEntity.self)
        registry.register(AutomationEntity.self)
        registry.register(ClimateEntity.self)
    }

    static func deleteStore(at url: URL) {
        let base = url.deletingPathExtension()
        let name = base.lastPathComponent
        let dir = base.deletingLastPathComponent()
        for suffix in [".store", ".store-wal", ".store-shm"] {
            let fileURL = dir.appending(path: name + suffix)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                // File already absent — nothing to clean up
            } catch {
                Log.warning("Failed to delete store file \(fileURL.lastPathComponent)", cause: error)
            }
        }
    }
}
