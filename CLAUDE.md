# Hemera

Hemera is an open-source Home Assistant client for iOS, built with SwiftUI. Licensed under MIT.

## Quick Reference

| | |
|---|---|
| **Language** | Swift 6 (strict concurrency) |
| **UI Framework** | SwiftUI with `@Observable` (not ObservableObject/Combine) |
| **Persistence** | SwiftData |
| **Min Target** | iOS 18+, Xcode 26+ |
| **Architecture** | MVVM + Coordinator + Service Locator |
| **Remote Dependency** | HAKit (Home Assistant WebSocket/REST SDK) |
| **Local Packages** | Mortar (design system), TileGridEngine (tile layout), HemeraLog (logging), AppStoreScreenshots |

## Project Structure

```
seville/
├── Hemera/                          # Main app target
│   ├── HemeraApp.swift              # @main entry point
│   ├── AppEnvironment.swift         # App-lifetime container (SwiftData, ScreenManager)
│   ├── ServiceLocator.swift         # Session-scoped DI hub
│   ├── SessionManager.swift         # Session lifecycle (connect/disconnect/demo)
│   ├── Auth/                        # OAuth flow, token refresh, Keychain
│   ├── Demo/                        # DemoDataProvider, DemoController
│   ├── Entities/                    # Per-domain entity modules (Light, Cover, Switch, etc.)
│   │   ├── <Domain>/               # One directory per HA domain
│   │   │   ├── <Domain>Entity.swift
│   │   │   ├── <Domain>Controlling.swift
│   │   │   ├── <Domain>Controller.swift  # Production controller (wraps HAServiceCalling)
│   │   │   └── UI/                  # Card view, card VM, optional control panel
│   │   ├── EntityCardViewModel.swift
│   │   └── ViewModelFactory.swift
│   ├── HomeAssistant/               # HAConnectionManager, HADataSyncService, HAServiceCaller, HARESTClient
│   ├── Navigation/                  # AppRouter, AppCoordinator, DemoCoordinator
│   ├── Persistency/                 # StoredEntity, EntityRegistry, BackgroundSyncStorage, repositories
│   ├── Screen/                      # ScreenManager (stay-awake, dim-after-inactivity)
│   └── UI/                          # SwiftUI views + view models
├── HemeraTests/                     # Unit tests (Swift Testing framework)
├── HemeraUITests/                   # Screenshot capture (XCTest)
├── Packages/
│   ├── Mortar/                      # Design system: EntityCard, VerticalSlider, PillPicker, tokens
│   ├── TileGridEngine/              # Tile layout algorithm (pure logic, own test suite)
│   ├── HemeraLog/                   # Logging utility wrapping os.Logger
│   └── AppStoreScreenshots/         # Promo screenshot compositing
├── Config/
│   ├── Shared.xcconfig
│   └── Local.xcconfig.template      # Per-developer signing (DEVELOPMENT_TEAM)
├── .claude/                         # Claude Code configuration
│   ├── settings.json                # Allowed/denied shell commands
│   ├── rules/                       # Conventions (architecture, style, testing)
│   └── commands/                    # Custom slash commands
├── scripts/
│   ├── capture-screenshots.sh
│   └── generate-promo-screenshots.sh
```

## Setup

1. Clone the repository.
2. `cp Config/Local.xcconfig.template Config/Local.xcconfig`
3. Edit `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM` to your Apple Team ID.
4. Open `Hemera.xcodeproj` in Xcode and build.

## Build & Test Commands

Build the app:
```bash
xcodebuild build -project Hemera.xcodeproj -scheme Hemera -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Run unit tests:
```bash
xcodebuild test -project Hemera.xcodeproj -scheme Hemera -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HemeraTests
```

Run a single test class:
```bash
xcodebuild test -project Hemera.xcodeproj -scheme Hemera -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:HemeraTests/ButtonCardViewModelTests
```

Run UI tests (screenshot capture):
```bash
xcodebuild test -project Hemera.xcodeproj -scheme Hemera -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' -only-testing:HemeraUITests/ScreenshotTests
```

Run SPM package tests:
```bash
swift test --package-path Packages/TileGridEngine
swift test --package-path Packages/AppStoreScreenshots
```

## Architecture Overview

Full conventions are in `.claude/rules/architecture.md`.

### Key Patterns

- **MVVM + Coordinator**: Each screen has an `@Observable` ViewModel. Navigation is driven by `AppRouter` (destination enum), coordinated by `AppCoordinator` and `DemoCoordinator`.
- **Service Locator**: `ServiceLocator.shared` provides session-scoped dependencies (`ViewModelFactory`, repositories). Configured at app start, populated per-session by `SessionManager`.
- **Protocol-based DI**: Domain operations use protocols (`LightControlling`, `CoverControlling`, etc.). Three implementations: production (`HAServiceCaller`), demo (`DemoController`), test (hand-written mocks).
- **Entity pattern**: Each Home Assistant domain has a SwiftData `@Model` conforming to `StoredEntity`, a controlling protocol, and a `CardViewModel` conforming to `EntityCardViewModel`. All registered in `EntityRegistry` at startup.
- **BackgroundSyncStorage**: A `@ModelActor` for off-main-thread SwiftData writes during initial bulk sync.

### Data Flow

See `.claude/rules/architecture.md` for the full data flow diagram and dependency ownership tree.

- **Initial sync**: `HA Server → HAConnectionManager → HADataSyncService → BackgroundSyncStorage → SwiftData mainContext → ViewModelFactory → SwiftUI Views`
- **Real-time updates**: `HA Server → HAConnectionManager → HADataSyncService → mainContext (direct) → @Model observation → SwiftUI Views`

### Mortar Design System (`Packages/Mortar`)

Custom component library providing the visual foundation for the app. Always use Mortar tokens over raw values — see `.claude/rules/swift-style.md` for the full token reference.

**Components**: `EntityCard`, `CardIcon`, `CardLabel`, `CardRow`, `CardBackground`, `EntityControlPanel`, `VerticalSlider`, `PillPicker`

**Token namespaces**: `Mortar.Spacing`, `Mortar.Motion`, `Mortar.Radii`, `Mortar.Shadow`, `Mortar.StrokeWidth`, `Mortar.IconSize`, `Mortar.SemanticColor`, `Mortar.PlatformColors`

## Common Workflows

### Adding a new Home Assistant entity type

1. Create `Hemera/Entities/<Domain>/` directory.
2. Add `<Domain>Entity.swift` — `@Model` conforming to `StoredEntity` with `static let domain`, `update(from:)`, `entityIdPredicate(_:)`, and `unassignedPredicate`. Predicates must use `#Predicate` at the concrete type level (never in generic or protocol-extension scope).
3. Add a `@Relationship(inverse: \<Domain>Entity.area)` property to `AreaEntity.swift`.
4. Add `<Domain>Controlling.swift` — `@MainActor` protocol with domain-specific control methods (`func ... async`).
5. Add `UI/<Domain>CardViewModel.swift` — `@Observable @MainActor final class` conforming to `EntityCardViewModel` with `makeCardView()` and optionally `makeOverlayView(isPresented:)`. Include a `static func registration(controller:) -> ViewModelFactory.Registration` method.
6. Add `UI/<Domain>Card.swift` — SwiftUI view using `EntityCard` from Mortar.
7. Optionally add `UI/<Domain>ControlPanel.swift` for a detail overlay.
8. Register the entity type in `AppEnvironment.registerEntities()`.
9. Add `<Domain>Controller.swift` — `@MainActor final class` conforming to the controlling protocol, wrapping `HAServiceCalling` + `ErrorNotifier`.
10. Add a parameter to `ViewModelFactory.registerAllDomains()` and wire it in `SessionManager`.
11. Conform `DemoController` to the new controlling protocol.
12. Add demo data in `DemoDataProvider`.
13. Add the protocol to `MockController` in tests.
14. Add the new domain to `EntityCategory.from(domain:)` in `Hemera/Entities/EntityCategory.swift` so entities appear in the correct category section in area detail views.

### Adding a new screen

1. Create a ViewModel — `@Observable @MainActor final class`.
2. Inject dependencies as protocols via initializer.
3. Add the SwiftUI view in `Hemera/UI/`.
4. Wire navigation through `AppRouter` if it's a root-level destination.
