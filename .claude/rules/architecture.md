# Architecture Conventions

## MVVM + Coordinator

Every screen follows the same structure:
- A **View** (SwiftUI `struct`) that is purely declarative — no business logic.
- A **ViewModel** (`@Observable @MainActor final class`) that owns all state and logic.
- Navigation decisions are made by **Coordinators** (`AppCoordinator`, `DemoCoordinator`), not by views or view models.
- `AppRouter` holds the current `Destination` enum and is the single source of truth for which root view is displayed.

### ViewModel Rules

- Always `@Observable` — never `ObservableObject` or `@Published`.
- Always `@MainActor`.
- Always `final class`.
- Inject dependencies via initializer as protocols.
- Keep a testable init that accepts protocols, and optionally a convenience init that pulls from `ServiceLocator.shared`.

```swift
@Observable
@MainActor
final class SomeViewModel {
    // Testable init — accepts protocols
    init(repository: some HomeTileRepository, factory: ViewModelFactory) { ... }
}
```

For ViewModels that only use app-lifetime deps, a `convenience init()` pulls from `ServiceLocator.shared`. For ViewModels that need session-scoped deps, the parent view resolves the `Session` and passes deps via the testable init.

## Service Locator

`ServiceLocator.shared` is the dependency container (`ServiceLocator.swift`).

- Configured once at app start with long-lived dependencies: `authManager`, `router`, `demoCoordinator`, `sessionManager`, `screenManager`.
- Session-scoped dependencies are bundled in a `Session` struct (`Session.swift`), stored as `var session: Session?`. Created atomically by `SessionManager` when sessions start, nilled on teardown.
- `Session` contains: `connectionStatusProvider`, `areaRepository`, `homeTileRepository`, `viewModelFactory`, `restClient`, `errorNotifier`. All non-optional — a Session is always complete.
- `MainTabView` resolves `sl.session!` once in its `init` and injects deps into child ViewModels via their testable inits.
- Do not add new singleton services here without discussion. Prefer protocol-based injection.

## Protocol-Based Dependency Injection

Every external capability is abstracted behind a protocol:
- `AuthManaging` — authentication state and token management
- `LightControlling`, `CoverControlling`, `SceneControlling`, `SwitchControlling`, `ButtonControlling`, `AutomationControlling`, `ClimateControlling` — entity domain operations
- `HARESTClienting` — Home Assistant REST API operations (version, area mappings)
- `HomeTileRepository`, `AreaRepository` — data access
- `Storage` — generic SwiftData read/write operations
- `DemoCoordinating` — demo mode lifecycle
- `ConnectionRetrying` — reconnection
- `SettingsStoring` — persistence of the user settings document

### User Settings

`Hemera/Settings/` splits into four pieces, each with one job:

- **`Settings`** — a plain `Codable` struct holding every setting. **Adding a setting is one line
  here**, with a default. Raw-valued enums must declare `Codable` — synthesis is free, the
  conformance is not.
- **`SettingsJSON`** — encoding and decoding. `decode(_:)` overlays what is stored onto the defaults
  before decoding, because the synthesized decoder ignores property defaults and throws
  `keyNotFound` — without it, shipping a new setting would wipe every existing one. There is no
  per-field recovery: a wrong-typed value returns `nil` and settings reset, so changing an existing
  setting's type goes through `SettingsMigration`.
- **`SettingsStoring`** / **`UserDefaultsSettingsStore`** — holds the current `Settings` and persists
  on mutation. A reference type so every owner mutates one shared value, but deliberately **not**
  `@Observable`.
- **`SettingsMigration`** — version policy: the legacy-key import, and the rule that each step is a
  no-op when its source data is absent.

**Each setting has exactly one owner** — the view model or manager that exposes it to the UI
(`ScreenManager` owns the kiosk settings; `AreasViewModel` owns `areasGroupedByFloor`). The owner
declares it as an observable stored property and writes through in `didSet`. Two owners holding
their own copies would diverge; if something cross-cutting ever appears, route both through one
owner rather than reading the store twice.

That ownership rule is why the store needs no observation: the UI observes the owners, which are
already `@Observable`. Settings deliberately do **not** live in SwiftData — that store is a cache of
HA state whose recovery path deletes it (`AppEnvironment.init`), and settings are the only
irreplaceable data in the app.

## Entity Pattern

Each Home Assistant domain (light, cover, switch, button, scene, automation, sensor, binary_sensor) follows a fixed module structure under `Hemera/Entities/`:

```
Entities/<Domain>/
├── <Domain>Entity.swift              # @Model conforming to StoredEntity
├── <Domain>Controlling.swift         # Protocol for domain operations
├── <Domain>Controller.swift          # Production controller wrapping HAServiceCalling
└── UI/
    ├── <Domain>CardViewModel.swift   # @Observable, conforms to EntityCardViewModel
    ├── <Domain>Card.swift            # SwiftUI view using EntityCard from Mortar
    └── <Domain>ControlPanel.swift    # Optional detail overlay
```

### StoredEntity Protocol (`Persistency/StoredEntity.swift`)

All entity models conform to `StoredEntity`, which provides:
- `static var domain: String` — the HA domain string (e.g., `"light"`)
- `var entityId: String` — unique identifier
- `var deviceId: String?` — parent device
- `var area: AreaEntity?` — area relationship
- `func update(from entity: HAEntity)` — sync from HA state
- `static func entityIdPredicate(_:) -> Predicate<Self>` — lookup by ID
- `static var unassignedPredicate: Predicate<Self>` — entities without an area
- Default implementations of `performUpsert`, `fetch(byId:)`, `assignAreaIfMatch`, `assignDeviceIdIfMatch`

**Important:** `entityIdPredicate` and `unassignedPredicate` must be implemented in each concrete `@Model` type — never in a protocol extension or generic function. `#Predicate` in generic/protocol-extension contexts causes SwiftData keypath identity mismatches in release builds.

### EntityCardViewModel Protocol (`Entities/EntityCardViewModel.swift`)

Provides type-erased rendering for heterogeneous entity collections:
- `makeCardView() -> AnyView` — card tile for grids
- `makeOverlayView(isPresented:) -> AnyView?` — detail control panel (default: `nil`)

### EntityRegistry (`Persistency/EntityRegistry.swift`)

- Write-once-read-many registry of entity types.
- Registered at startup in `AppEnvironment.registerEntities()`.
- Dispatches upserts and area assignments by domain string — no switch statements at the sync layer.

### ViewModelFactory (`Entities/ViewModelFactory.swift`)

- Creates `EntityCardViewModel` instances using a registration-based pattern.
- Each entity domain registers a `ViewModelFactory.Registration` via a static method on its CardViewModel (e.g., `LightCardViewModel.registration(controller:)`).
- `registerAllDomains(lightController:coverController:...)` — registers all built-in domains. Each domain's controller is passed individually as a protocol-typed parameter.
- `makeViewModels(for area:)` — all VMs for an area (delegates to registered factories).
- `makeViewModel(forEntityId:)` — single VM lookup (delegates to registered factories).

## Concurrency Model

- Swift 6 strict concurrency is enabled.
- Use `async/await` and structured `Task` throughout.
- View models and coordinators are `@MainActor`.
- `BackgroundSyncStorage` is a `@ModelActor actor` for off-main-thread SwiftData writes during initial bulk sync.
- Real-time `state_changed` events are written directly to `mainContext` so `@Model` property observation triggers SwiftUI updates.
- Entity controlling protocols are `@MainActor` — all callers (CardViewModels) and all conformers (HAServiceCaller, DemoController, MockController) are MainActor-isolated.
- Use `nonisolated(unsafe)` sparingly and only for write-once-read-many patterns (e.g., `EntityRegistry.shared`, `ServiceLocator._shared`).
- Never use `DispatchQueue`, `OperationQueue`, or `Thread`. Use Swift Concurrency primitives only.

## Demo Mode

Demo mode is a first-class feature, not an afterthought:
- `DemoDataProvider` seeds realistic SwiftData entities.
- `DemoController` conforms to all controlling protocols, simulating behavior by mutating `@Model` objects directly.
- `DemoCoordinator` manages enter/exit lifecycle. Its delegate (`AppCoordinator`) wires into `SessionManager` and `AppRouter`.
- UI tests run in demo mode via `-screenshotMode` launch argument.

## Navigation

- `AppRouter.Destination` enum drives root-level navigation: `.onboarding`, `.connectToServer`, `.connecting`, `.authenticated`.
- `AppRouter` reacts to `AuthManager` state changes automatically.
- `SessionManager` calls `router.sessionReady()` when the WebSocket sync completes.
- Sheet/overlay presentation is handled locally in views via `@State`/bindings, not centralized.

## Data Flow

```
Home Assistant Server
  ↓ WebSocket + REST
HAConnectionManager / HARESTClient
  ↓
HADataSyncService
  ├─ initial bulk sync ──→ BackgroundSyncStorage (@ModelActor)
  │                           ↓ SwiftData auto-merge
  └─ real-time updates ──→ mainContext (direct writes)
                              ↓ @Model property observation
ViewModelFactory → EntityCardViewModel instances
  ↓
SwiftUI Views
```

## Dependency Ownership

```
HemeraApp
  └─ AppEnvironment (SwiftData container, ScreenManager)
  └─ AuthManager (Keychain, token refresh)
  └─ AppRouter (destination state)
  └─ SessionManager (connects AppEnvironment + AuthManager → session objects)
       └─ HAConnectionManager, HADataSyncService (mainContext + BackgroundSyncStorage)
       └─ ViewModelFactory, repositories → registered on ServiceLocator
  └─ ServiceLocator.shared (provides session-scoped deps to views)
```
