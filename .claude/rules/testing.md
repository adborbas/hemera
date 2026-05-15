# Testing Conventions

## Frameworks

- **Unit tests**: Swift Testing (`import Testing`). Use `@Test` and `#expect`.
- **UI tests**: XCTest (`import XCTest`). Used exclusively for screenshot capture in demo mode.
- Do NOT use XCTest for unit tests. All new unit tests must use Swift Testing.

## Test Structure

### File Organization

```
HemeraTests/
├── Entities/          # Entity-specific VM and model tests
├── Mocks/             # Shared hand-written mocks
├── Navigation/        # Coordinator and router tests
├── Persistency/       # Repository and storage tests
└── UI/
    ├── Screens/Home/  # Home-related VM tests
    ├── Onboarding/    # Onboarding VM tests
    └── Settings/      # Settings VM tests
```

Mirror the main app's directory structure. Test files go in the same relative path as the code they test.

### Test Type Naming

- Test structs: `<TypeUnderTest>Tests` (e.g., `ButtonCardViewModelTests`, `HomeTileRepositoryTests`).
- Always `@MainActor struct` (since most code under test is `@MainActor`).
- Use struct `init()` for setup — no `setUp()`/`tearDown()` methods.

### Test Method Naming

Pattern: `func <methodUnderTest>_<scenario>_<expectedBehavior>()`

```swift
@Test func iconName_restart()
@Test func iconColor_restart_isOrange()
@Test func loadTiles_withHomeTiles_populatesSectionsAndContent()
@Test func demoDidExit_withConnectToServerTrue_navigatesToConnectToServer()
@Test func removeFromHome_delegatesToRepository()
```

Shorter names are fine when the scenario is obvious from the method name alone.

### Assertions

- Use `#expect(condition)` for all assertions.
- Use `#expect(a == b)` for equality — never `XCTAssertEqual`.
- For async operations that need settling time: `try await Task.sleep(for: .milliseconds(100))` then assert.

## Mocks

### Shared Mocks (`HemeraTests/Mocks/`)

Hand-written mock classes implementing the domain protocols:
- `MockController` — conforms to all controlling protocols with no-op implementations.
- `MockAuthManager` — tracks `didAuthenticateCallCount`, `logoutCallCount`, configurable `validAccessTokenResult`.
- `MockHomeTileRepository` — uses `stubbedHomeTiles`, `removeFromHomeCalls`, `reorderCalls`, `commitLayoutCalls`.
- `MockAreaRepository` — area-related tests.
- `MockRESTClient` — stubs `HARESTClienting` with configurable `stubbedVersion`, tracks `fetchVersionCallCount`.
- `MockDemoCoordinator`, `MockDemoCoordinatorDelegate`, `MockConnectionRetrier`.

### When to Create a Spy vs. a Stub

- **Stub** (default): Returns pre-configured values. No call tracking. Use when the dependency just needs to not crash.
- **Spy**: Tracks calls (count, arguments). Use when the test verifies an interaction happened.

Test-local spies are `private final class` in the test file. Shared mocks in `HemeraTests/Mocks/` are `@MainActor final class`.

### Spy Pattern

```swift
private final class SpyButtonControlling: ButtonControlling {
    var pressedIds: [String] = []

    func pressButton(_ id: String) async {
        await MainActor.run { pressedIds.append(id) }
    }
}
```

Use descriptive property names for tracked calls: `pressedIds`, `removeFromHomeCalls`, `commitLayoutCalls`.

Never use mocking frameworks. All mocks are hand-written.

## Test Data

### SwiftData in Tests

Use in-memory containers:
```swift
init() {
    let schema = Schema([LightEntity.self, AreaEntity.self, HomeTile.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    container = try! ModelContainer(for: schema, configurations: config)
    context = container.mainContext
}
```

Include only the entity types your test actually uses in the Schema.

### ServiceLocator in Tests

Tests exercising code that depends on `ServiceLocator.shared` must call `ServiceLocator.configure(...)` in their `init()`.

### Entity Factories

Create test entities with minimal required fields:
```swift
let light = LightEntity(entityId: "light.test", name: "Test", state: .on)
let button = ButtonEntity(entityId: "button.test", name: "Test", deviceClass: .restart)
```

## UI Tests

UI tests are exclusively for screenshot capture:
- Run in demo mode via `-screenshotMode` launch argument.
- Use `XCUIApplication.screenshotApp()` helper.
- Naming: `testScreenshot_<number>_<description>_<orientation>`.
- Use `sleep(1)` for animation settling before capturing.
- Do NOT add behavioral UI tests. Test behavior through unit tests of view models.

## SPM Package Tests

`TileGridEngine` and `AppStoreScreenshots` have their own test targets using Swift Testing:
```bash
swift test --package-path Packages/TileGridEngine
swift test --package-path Packages/AppStoreScreenshots
```

## What to Test

- **Always test**: ViewModel logic, coordinator behavior, repository operations, entity model behavior.
- **Do not test**: SwiftUI view rendering, Mortar component layout, direct SwiftData queries (test through repositories).
- **Test the boundary**: If a view model transforms data for display (e.g., computing `iconName` from `deviceClass`), that transformation is a good test target.
