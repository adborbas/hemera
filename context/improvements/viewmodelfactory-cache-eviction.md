# ViewModelFactory cache is never evicted — cached VMs can outlive their deleted @Model

> Hemera code-audit finding (2026-07-16). Self-contained brief for an implementation agent — assume no other context.

## Metadata
- Category: improvement
- Severity: low
- Verification: unverified (code-analysis only) — demo data is seeded once and never deleted during a session, so the invalid-model path is not exercised; requires an entity deleted from HA mid-session plus a later by-id access.
- Demo-reproducible: no
- Primary file(s): `Hemera/Entities/ViewModelFactory.swift:26,80-97`

## Context
`ViewModelFactory` (`@MainActor final class`) creates `EntityCardViewModel` instances from registered per-domain factories and caches them by `entityId` for the session's lifetime. Caching is intentional: the same `entityId` returns the same VM instance, preserving ephemeral interaction state (pending brightness values, `CommitCooldown`) across SwiftUI re-renders. Each cached VM holds a strong reference to its backing SwiftData `@Model`.

Area grids rebuild from `area.<relationship>` (e.g. `area.lights`), which drops deleted entities — so in normal rendering a stale VM is not shown. The by-id lookup `makeViewModel(forEntityId:)` and `handleCardTap(entityId:)`, however, return the cached VM without rechecking that the backing model still exists.

## Problem
- Symptom: Potential (unlikely) crash — "This model instance was invalidated" — if a cached VM's backing `@Model` is deleted mid-session and something later reads a property off that VM.
- Trigger: Entity deleted from Home Assistant during an active session, then its cached VM is accessed by id (via `makeViewModel(forEntityId:)` / `handleCardTap`).
- Root cause: `cache: [String: any EntityCardViewModel]` grows for the factory's whole lifetime with no eviction path. A cached VM strongly retains its `@Model`; if sync deletes that model, the VM (and the invalidated model) survive in the cache.

This is hardening, not a shipping bug — grids rebuild from relationships and drop deleted entities, so the stale VM is usually never rendered/accessed.

### Evidence
```swift
// Hemera/Entities/ViewModelFactory.swift:26 — session-lifetime cache, no eviction
private var cache: [String: any EntityCardViewModel] = [:]
```
```swift
// Hemera/Entities/ViewModelFactory.swift:80-89 — by-id lookup returns cached VM with no existence recheck
func makeViewModel(forEntityId entityId: String) -> (any EntityCardViewModel)? {
    if let cached = cache[entityId] { return cached }  // no re-validation that the model still exists
    for registration in registrations {
        if let vm = registration.makeViewModelForEntityId(entityId, context) {
            cache[entityId] = vm
            return vm
        }
    }
    return nil
}
```

## Reproduction / how to observe
Not reproducible in demo mode. Would require: (1) a live session where an entity is removed from HA and its `@Model` deleted from the context, and (2) a subsequent `makeViewModel(forEntityId:)`/`handleCardTap` for that id that reads a model-backed property. In practice the grid stops referencing it first.

## Suggested solution
Two options; pick the lighter one that fits how deletions flow through the sync layer.

Option A (preferred — evict on deletion): Add an eviction method and call it where entities are deleted during sync.
```swift
// ViewModelFactory
func evict(entityId: String) {
    cache[entityId] = nil
}
func evict(entityIds: some Sequence<String>) {
    for id in entityIds { cache[id] = nil }
}
```
Wire it into the sync/deletion path. Read `Hemera/HomeAssistant/HADataSyncService.swift` and `Hemera/Persistency/` (EntityRegistry, BackgroundSyncStorage, repositories) to find where models are deleted, and confirm the factory is reachable there (it lives on `ServiceLocator.shared.session?.viewModelFactory`). Only wire it if there is a clean, single deletion chokepoint — do not scatter eviction calls.

Option B (defensive guard at lookup): In `makeViewModel(forEntityId:)`, when a cached VM exists, re-verify the backing model is still present before returning it, evicting on miss:
```swift
func makeViewModel(forEntityId entityId: String) -> (any EntityCardViewModel)? {
    if let cached = cache[entityId] {
        // Re-confirm the backing entity still exists; drop the stale VM otherwise.
        if entityStillExists(entityId) { return cached }
        cache[entityId] = nil
    }
    ...
}
```
The challenge: existence checking is per-domain (`LightEntity.fetch(byId:)`, etc.), and the factory is domain-agnostic. Rebuilding via `registration.makeViewModelForEntityId` on every by-id call would defeat the state-preservation purpose of the cache. So Option B is only clean if a domain-agnostic "does any registered entity with this id exist" check is cheap — otherwise prefer Option A.

Trade-offs / confirm: The class doc explicitly calls the session-lifetime cache intentional; this is hardening. Do not add eviction unless there is a genuine deletion chokepoint to hook — an unused `evict` method is dead code. If no clean hook exists, it may be acceptable to document the risk and defer. Surface that finding rather than force a fix.

## Acceptance criteria
- [ ] Deleting an entity mid-session no longer leaves a cached VM that can be returned by `makeViewModel(forEntityId:)`/`handleCardTap` referencing an invalidated `@Model`.
- [ ] The cache still preserves interaction state across re-renders for live entities (no regression to pending values / cooldowns).
- [ ] Eviction is wired at a single, correct deletion chokepoint (Option A) OR a domain-agnostic existence guard is added (Option B) — whichever is cleaner given the sync layer; if neither is clean, the risk is documented and the change deferred with rationale.
- [ ] Tests added/updated per `.claude/rules/testing.md` where feasible (Swift Testing, `#expect`): with an in-memory container, cache a VM via `makeViewModel(forEntityId:)`, delete the model, evict (or re-lookup), and `#expect` the stale VM is not returned. Include the needed `@Model` types in the test `Schema`.
- [ ] Demo mode unaffected.

## Files to read first
- `Hemera/Entities/ViewModelFactory.swift`
- `Hemera/Entities/EntityCardViewModel.swift`
- `Hemera/HomeAssistant/HADataSyncService.swift` (where deletions happen)
- `Hemera/Persistency/EntityRegistry.swift`, `Hemera/Persistency/BackgroundSyncStorage.swift`
- `Hemera/ServiceLocator.swift` / `Hemera/Session.swift` (how the factory is reached)
