# Swift & SwiftUI Style Guide

## Naming

- Types: `UpperCamelCase` — `LightCardViewModel`, `EntityRegistry`.
- Properties, functions, parameters: `lowerCamelCase`.
- Protocols describing capabilities: `-ing` or `-able` suffix — `LightControlling`, `AuthManaging`, `DemoCoordinating`, `ConnectionRetrying`.
- Protocols describing a role: noun form — `HomeTileRepository`, `AreaRepository`, `Storage`.
- Home Assistant types use `HA` prefix — `HAConnectionManager`, `HADataSyncService`, `HARESTClient`, `HAServiceCaller`.

## Access Control

- Default to `internal` (implicit).
- Use `private` for implementation details. Prefer `private` over `fileprivate`.
- Use `private(set)` for read-only observable properties.
- SPM packages (`Mortar`, `TileGridEngine`, `HemeraLog`) must use explicit `public`.

## Type Design

- `struct` for value types and data models without identity.
- `final class` for reference types (view models, managers, coordinators).
- `enum` with no cases for namespaces (e.g., `Mortar`, `DemoDataProvider`, `Localization` enums).
- `actor` only for background isolation (`BackgroundSyncStorage`).
- Always mark classes `final` — inheritance is not used in this project.

## File Organization

Use `// MARK: -` to organize sections:
- `// MARK: - Properties`, `// MARK: - Init`, `// MARK: - Public Methods`, `// MARK: - Private Methods`
- `// MARK: - ProtocolName` for protocol conformance in extensions

Group protocol conformances into separate extensions. Private helpers go in `private extension TypeName { }`.

## Comments

- **Multi-line comments use the `/** ... */` block form.** This applies to *every* comment that spans more than one line — both explanatory comments and documentation comments. Never stack `//` lines or use a `/* ... */` block for a multi-line comment.
- **Single-line comments stay `//`** (or `///` for a single-line doc comment). `// MARK: -` section markers are always `//`, regardless.

```swift
/**
 Sorted, non-degenerate temperature range for the slider track.
 Guards against a server reporting min > max, which would trap the ClosedRange.
*/
private var temperatureRange: ClosedRange<Double> { ... }

// A single-line explanatory comment stays as a one-line //.
```

## Error Handling

- Use `throws` / `try await` for recoverable errors.
- Use `try?` only when failure is genuinely ignorable.
- Use `preconditionFailure` for programmer errors (e.g., `ServiceLocator` accessed before configuration).

## SwiftUI Views

- Views are `struct` — never class.
- Keep views small and composable. Extract subviews into separate types or `@ViewBuilder` properties.
- Wrap previews in `#if DEBUG` / `#Preview { }` / `#endif`.
- Preview mocks are `fileprivate` in the same file — they do not go in `HemeraTests/Mocks/`.

### Toolbar Icon Buttons

**Never use `Image(systemName:)` inside toolbar buttons.** SwiftUI sizes the hosting view to match the SF Symbol pixels, but UIKit renders a larger circular platter background around it. The result is a tap target limited to the tiny icon area — taps on the visible platter circle don't register.

**Always use `Label` with `.labelStyle(.iconOnly)`:**

```swift
// WRONG — broken tap target
ToolbarItem(placement: .cancellationAction) {
    Button { dismiss() } label: {
        Image(systemName: "xmark")
    }
}

// CORRECT — tap target fills the full platter
ToolbarItem(placement: .cancellationAction) {
    Button { dismiss() } label: {
        Label(Localization.close, systemImage: "xmark")
            .labelStyle(.iconOnly)
    }
}
```

The `Label` text also provides accessibility for free. Use a localized string from the view's `Localization` enum.

Dismiss/close buttons go on the leading side using `.cancellationAction` placement (Apple HIG).

## State Management

- `@State` for view-local state.
- `@Environment` for injected dependencies.
- `@Binding` for two-way parent-child communication.
- **Never** use `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, or Combine `@Published`. These are legacy. Use `@Observable` with `@State` / `@Environment` instead.

## Observation

- View models use the `@Observable` macro (Swift Observation framework).
- Views reference view models as plain properties or via `@State`.
- Never manually call `objectWillChange` — it does not exist in `@Observable`.

## Mortar Design System

Always use Mortar tokens over raw values:

**Spacing**: `Mortar.Spacing.xxs` (2) through `.xxl` (24) — never hardcode spacing values.

**Animation**: Use `Mortar.Motion` tokens:
```swift
.animation(Mortar.Motion.springNormal, value: someValue)
.animation(.spring(duration: Mortar.Motion.fast), value: someValue)
```

**Corner radii**: `Mortar.Radii.s` (12) through `.xl` (36).

**Shadows**: `.mortarShadow(.subtle)`, `.mortarShadow(.soft)`, `.mortarShadow(.medium)`.

**Components**: Use `EntityCard`, `CardIcon`, `CardLabel`, `CardRow`, `CardBackground` for entity cards. Use `EntityControlPanel` for detail overlays. Use `VerticalSlider` and `PillPicker` for controls.

## Localization

All user-facing strings use `String(localized:comment:)`. Group them in a `private enum Localization` nested in the type via a private extension:

```swift
private extension AppRouter {
    enum Localization {
        static let sessionExpired = String(
            localized: "Your session has expired. Please log in again.",
            comment: "Message shown on the welcome screen after the user's authentication session expires"
        )
    }
}
```

Always include a descriptive `comment` parameter explaining context for translators.

## SwiftData

- Entity models use the `@Model` macro.
- Use `@Attribute(.unique)` for `entityId` fields.
- Initial bulk sync writes go through `BackgroundSyncStorage` (`@ModelActor`). Real-time updates write to `mainContext` directly for observation.
- Use `FetchDescriptor` with `#Predicate` for queries.
- In-memory containers for tests: `ModelConfiguration(isStoredInMemoryOnly: true)`.

## Swift Concurrency

- `@MainActor` on all view models, coordinators, and managers.
- `nonisolated` on protocol methods callable from any context (all controlling protocol methods).
- `@Sendable` closures when crossing isolation boundaries.
- For shared mutable state, prefer `Mutex` from the `Synchronization` framework over `nonisolated(unsafe)`. `nonisolated(unsafe)` remains acceptable for write-once singletons of `@MainActor` types (e.g., `ServiceLocator._shared`).
- Never use `DispatchQueue`, `OperationQueue`, or `Thread`.
