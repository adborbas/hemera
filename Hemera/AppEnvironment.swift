import Foundation
import HemeraLog
import SwiftData
import UIKit

/// App-lifetime dependency container: SwiftData, entity registry, storage.
///
/// Session lifecycle (HA connections, demo sessions) lives in `SessionManager`.
@MainActor
final class AppEnvironment {

    let container: ModelContainer
    let storage: Storage
    let screenManager: ScreenManager
    let themeManager: ThemeManager
    let updateNudge: UpdateNudge
    let settingsStore: any SettingsStoring

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
            do {
                self.container = try ModelContainer(for: schema, configurations: modelConfig)
            } catch {
                Log.error("ModelContainer recreation failed after store deletion — falling back to in-memory container (no persistence this session). Error: \(error)")
                let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: memoryConfig)
            }
        }

        self.storage = SwiftDataStorage(context: container.mainContext)
        self.settingsStore = UserDefaultsSettingsStore()
        self.screenManager = ScreenManager(store: settingsStore)
        self.themeManager = ThemeManager(store: settingsStore)
        self.updateNudge = UpdateNudge(
            lookup: AppStoreClient(),
            screenManager: screenManager,
            installedVersion: Bundle.main.appVersion,
            osVersion: UIDevice.current.systemVersion,
            mayCheck: {
                guard !ServiceLocator.shared.demoCoordinator.isActive else { return false }
                return await AppStoreClient.isProductionBuild()
            }
        )
    }
}

// MARK: - Schema

extension AppEnvironment {
    /// Single source for the store's models, so the schema and the logout wipe cannot drift apart.
    static var allModelTypes: [any PersistentModel.Type] {
        EntityRegistry.shared.allEntityTypes + [AreaEntity.self, FloorEntity.self, HomeTile.self]
    }

    static func createSchema() -> Schema {
        Schema(allModelTypes)
    }
}

// MARK: - Entity Configuration

private extension AppEnvironment {

    static func registerEntities() {
        let registry = EntityRegistry.shared
        registry.register(LightEntity.self)
        registry.register(CoverEntity.self)
        registry.register(SceneEntity.self)
        registry.register(ScriptEntity.self)
        registry.register(SensorEntity.self)
        registry.register(BinarySensorEntity.self)
        registry.register(SwitchEntity.self)
        registry.register(ButtonEntity.self)
        registry.register(AutomationEntity.self)
        registry.register(ClimateEntity.self)
        registry.register(VacuumEntity.self)
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
