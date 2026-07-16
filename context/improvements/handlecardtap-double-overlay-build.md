# handleCardTap builds an overlay view solely to nil-check it, then discards it

> Hemera code-audit finding (2026-07-16). Self-contained brief for an implementation agent — assume no other context.

## Metadata
- Category: improvement
- Severity: low
- Verification: unverified (code-analysis only) — no user-visible effect; SwiftUI view structs have no side effects in init, so this is a minor wastefulness cleanup.
- Demo-reproducible: n/a
- Primary file(s): `Hemera/Entities/ViewModelFactory.swift:104-111`; `Hemera/Entities/EntityCardViewModel.swift:12-34`

## Context
`ViewModelFactory.handleCardTap(entityId:)` decides what a card-body tap does: if the entity has a detail overlay it returns the VM (the caller then presents the overlay); otherwise it invokes the entity's primary action in place and returns `nil`. Overlay creation is defined by `EntityCardViewModel.makeOverlayView(isPresented:) -> AnyView?`, with a protocol-extension default returning `nil` (entities like scenes have no overlay; lights/covers/switches/climate do).

## Problem
- Symptom: None visible to the user. On every card tap of an entity with an overlay, the overlay `AnyView` is constructed twice — once inside `handleCardTap` just to test `!= nil`, then discarded, then built again by the presenting caller.
- Trigger: Any card tap on an entity that has an overlay (light, cover, switch, climate).
- Root cause: Overlay existence is probed by materializing the view (`vm.makeOverlayView(isPresented: .constant(true)) != nil`) rather than via a cheap capability flag.

### Evidence
```swift
// Hemera/Entities/ViewModelFactory.swift:104-111 — current code
func handleCardTap(entityId: String) -> (any EntityCardViewModel)? {
    guard let vm = makeViewModel(forEntityId: entityId), vm.isAvailable else { return nil }
    if vm.makeOverlayView(isPresented: .constant(true)) != nil {  // constructs + discards a view
        return vm
    }
    vm.performPrimaryAction()
    return nil
}
```
```swift
// Hemera/Entities/EntityCardViewModel.swift:22-34 — protocol requirement + default nil overlay
func makeOverlayView(isPresented: Binding<Bool>) -> AnyView?
func performPrimaryAction()
...
extension EntityCardViewModel {
    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? { nil }
    func performPrimaryAction() { }
}
```

## Reproduction / how to observe
No runtime symptom. Observable only by code inspection or by adding a print in a `makeOverlayView` body and tapping a card — it is entered an extra time per tap.

## Suggested solution
Add a lightweight capability flag to the protocol and branch on it instead of materializing the view.

1. In `EntityCardViewModel` add the requirement with a default matching the current no-overlay default:
```swift
/// Whether this entity presents a detail overlay when its card body is tapped.
var hasOverlay: Bool { get }
...
extension EntityCardViewModel {
    var hasOverlay: Bool { false }          // default: no overlay (matches default makeOverlayView == nil)
    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? { nil }
    func performPrimaryAction() { }
}
```
2. Override `hasOverlay` to `true` in the VMs that provide an overlay — `LightCardViewModel`, `CoverCardViewModel`, `SwitchCardViewModel`, `ClimateCardViewModel` (i.e. every type that overrides `makeOverlayView` to return non-nil). Grep `makeOverlayView` across `Hemera/Entities/*/UI/*CardViewModel.swift` to enumerate them precisely and keep the two in sync. VMs that rely on the default (e.g. scenes, buttons, sensors) keep `hasOverlay == false`.
3. Branch on the flag:
```swift
func handleCardTap(entityId: String) -> (any EntityCardViewModel)? {
    guard let vm = makeViewModel(forEntityId: entityId), vm.isAvailable else { return nil }
    if vm.hasOverlay {
        return vm
    }
    vm.performPrimaryAction()
    return nil
}
```

Trade-off / correctness note: `hasOverlay` and `makeOverlayView` must not drift — a VM returning a non-nil overlay but `hasOverlay == false` would silently make its card tap invoke `performPrimaryAction` instead of presenting. Keep the override adjacent to `makeOverlayView` in each VM. Related note: the on/off-light fix (`context/bugs/onoff-light-brightness-slider.md`) may make `LightCardViewModel.makeOverlayView` return `nil` for non-dimmable lights — if that fix lands, `hasOverlay` for lights should reflect the same condition (e.g. `!supportedModes.isEmpty`) rather than a hardcoded `true`. Coordinate the two if both are implemented.

## Acceptance criteria
- [ ] `EntityCardViewModel` has a `hasOverlay` capability flag (default `false`); every VM whose `makeOverlayView` returns non-nil overrides it to `true` (or to the matching condition).
- [ ] `handleCardTap` branches on `hasOverlay` and no longer constructs an overlay view just to nil-check it.
- [ ] Card-tap behavior is unchanged for all domains: entities with overlays still present them; scenes/buttons/etc. still invoke `performPrimaryAction`.
- [ ] Tests added/updated per `.claude/rules/testing.md` where feasible (Swift Testing, `#expect`): assert `hasOverlay` matches whether `makeOverlayView` returns non-nil for each domain VM (e.g. `hasOverlay_scene_isFalse()`, `hasOverlay_switch_isTrue()`).
- [ ] Demo mode unaffected.

## Files to read first
- `Hemera/Entities/ViewModelFactory.swift`
- `Hemera/Entities/EntityCardViewModel.swift`
- `Hemera/Entities/*/UI/*CardViewModel.swift` (which override `makeOverlayView` non-nil)
- `context/bugs/onoff-light-brightness-slider.md` (light overlay may become conditional)
