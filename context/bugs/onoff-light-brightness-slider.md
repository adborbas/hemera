# On/off-only lights are given a non-functional brightness slider and fill

> Hemera code-audit finding (2026-07-16). Self-contained brief for an implementation agent — assume no other context.

## Metadata
- Category: bug
- Severity: medium
- Verification: unverified (code-analysis only) — every demo light in `DemoDataProvider` includes `"brightness"` in its color modes, so no on/off-only light exists in demo mode; requires a real HA server exposing `supported_color_modes: ["onoff"]`.
- Demo-reproducible: no
- Primary file(s): `Hemera/Entities/Light/UI/LightCardViewModel.swift:52-67`; related `Hemera/Entities/Light/UI/LightControlPanel.swift:8,77-129`; `Hemera/Entities/Light/UI/LightCard.swift:8-11,24-28`

## Context
Hemera follows a per-domain entity pattern. Each Home Assistant domain has an `@Observable @MainActor final class` CardViewModel conforming to `EntityCardViewModel`, a SwiftUI `Card` view (grid tile) and an optional `ControlPanel` overlay.

For lights:
- `LightCardViewModel.supportedModes` returns a `[LightControlMode]` (`.brightness`, `.colorTemp`, `.hue`) describing which control sliders the panel should offer.
- `LightControlPanel` renders a `VerticalSlider` per mode and a `PillPicker` to switch modes; the picker is hidden when `supportedModes.count <= 1`. `currentMode` is `@State` defaulting to `.brightness`, and the `slider` `@ViewBuilder` unconditionally renders a brightness `VerticalSlider(range: 0...255)` for `.brightness`.
- `LightCard` (medium tile) draws a `CardFillOverlay` whose `fillFraction` is `viewModel.brightness / 255.0`.
- Tapping the card body opens the overlay (`makeOverlayView`); tapping the icon calls `toggle()`.

Home Assistant's `"onoff"` color mode explicitly means the light has NO brightness — it is a plain on/off light.

## Problem
- Symptom: A non-dimmable light (`supported_color_modes: ["onoff"]`, no `brightness` attribute) opens a control panel with a 0–255 brightness slider that appears functional but does nothing useful. Dragging it sends `brightness` to a light that cannot dim (HA ignores/warns). The medium tile also renders a brightness fill for a device that has no brightness (fraction is always 0 since `light.brightness` is nil, so the fill is dead/empty).
- Trigger: Any light reporting `supported_color_modes: ["onoff"]`; open its control panel or view it as a medium tile.
- Root cause: `supportedModes` unconditionally seeds `.brightness`. The nil guard returns `[.brightness]`, and the non-nil path starts `result = [.brightness]`. Only `color_temp` and hue modes are conditionally appended; the `"onoff"`-only case is never excluded.

### Evidence
```swift
// Hemera/Entities/Light/UI/LightCardViewModel.swift:52-67 — current code
var supportedModes: [LightControlMode] {
    guard let modes = light.supportedColorModes else { return [.brightness] }
    var result: [LightControlMode] = [.brightness]
    if modes.contains("color_temp") {
        if light.minMireds != nil && light.maxMireds != nil {
            result.append(.colorTemp)
        } else {
            Log.warning("Light \(id) supports color_temp but is missing min_mireds/max_mireds — color temp control disabled")
        }
    }
    let hueModes: Set<String> = ["hs", "xy", "rgb", "rgbw", "rgbww"]
    if !hueModes.isDisjoint(with: modes) {
        result.append(.hue)
    }
    return result
}
```

```swift
// Hemera/Entities/Light/UI/LightControlPanel.swift:8 — currentMode defaults to .brightness
@State private var currentMode: LightControlMode = .brightness
```
```swift
// Hemera/Entities/Light/UI/LightControlPanel.swift:77-91 — brightness slider is rendered for .brightness regardless of supportedModes
@ViewBuilder
private var slider: some View {
    switch currentMode {
    case .brightness:
        VerticalSlider(
            value: $brightness,
            configuration: .init(range: 0...255, style: .fill(.bottom))
        ) { value in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.setBrightness(to: Int(value))
        }
        ...
```

## Reproduction / how to observe
Not reproducible in demo mode. Against a real HA server:
1. Expose a light with `supported_color_modes: ["onoff"]` (e.g. a smart plug/relay driving a lamp) and no `brightness` attribute.
2. In Hemera, tap the light's card body → the control panel opens showing a 0–255 brightness slider.
3. Drag the slider → `setBrightness` is sent; the light does not dim (HA rejects/ignores). The slider position is meaningless.
4. As a medium tile, the card shows a brightness fill overlay that is always empty (brightness nil → fraction 0).

## Suggested solution
Exclude `.brightness` when the light's color modes are only `["onoff"]`, then make the panel and card degrade gracefully to a toggle-only presentation.

1. In `supportedModes`, when the modes contain nothing but `"onoff"`, return an empty list:
```swift
var supportedModes: [LightControlMode] {
    guard let modes = light.supportedColorModes else { return [.brightness] }
    // A light whose only color mode is "onoff" has no brightness/color controls.
    if modes == ["onoff"] { return [] }
    var result: [LightControlMode] = [.brightness]
    ...
}
```
Note `light.supportedColorModes` type: confirm whether it is `[String]` or `Set<String>` before using `== ["onoff"]`. If it is a `Set`, compare `modes == ["onoff"]` still works; if it is an ordered `[String]`, prefer `Set(modes) == ["onoff"]` to be order-insensitive. Read `LightEntity.swift` for the declared type.

2. In `LightControlPanel`, guard the empty case so no dead slider shows. Minimal option — render a simple power toggle instead of the slider when `supportedModes.isEmpty`, mirroring the pattern in `Hemera/Entities/Switch/UI/SwitchControlPanel.swift` (a large power `Button` bound to `viewModel.isOn` calling `viewModel.toggle()`). Alternatively, have `LightCardViewModel.makeOverlayView` return `nil` when `supportedModes.isEmpty` so tapping the body does nothing and the only control is the card icon toggle. Prefer the power-toggle panel for consistency with switches (users expect the card body to open a panel).

3. In `LightCard`, suppress the fill for non-dimmable lights so the empty overlay is not drawn. Add a `isDimmable`/`hasBrightness` flag on the VM (e.g. `var isDimmable: Bool { supportedModes.contains(.brightness) }`) and gate `CardFillOverlay` on it:
```swift
} backgroundOverlay: {
    if isMediumTile && viewModel.isDimmable {
        CardFillOverlay(fraction: fillFraction, fillColor: viewModel.tintColor, anchor: .bottom)
    }
}
```

Trade-off / confirm: The `nil`-guard early return `return [.brightness]` (when `supportedColorModes` is entirely absent) is intentionally optimistic — leave it. Only the explicit `["onoff"]` case is being corrected. Confirm the `supportedColorModes` storage type before writing the equality check.

## Acceptance criteria
- [ ] A light with `supported_color_modes: ["onoff"]` yields `supportedModes == []`.
- [ ] Opening such a light's overlay shows only an on/off control (power toggle) — no brightness slider, no mode picker.
- [ ] The medium tile does not render a brightness fill overlay for a non-dimmable light.
- [ ] Dimmable lights (brightness/color_temp/hue) and lights with absent `supportedColorModes` are unchanged.
- [ ] Tests added/updated per `.claude/rules/testing.md` where feasible (Swift Testing, `#expect`): e.g. `supportedModes_onoffOnly_isEmpty()`, `supportedModes_brightnessOnly_containsBrightness()`, `isDimmable_onoffOnly_isFalse()`. Build `LightEntity` test fixtures with the appropriate `supportedColorModes`.
- [ ] Demo mode unaffected (all demo lights remain dimmable).

## Files to read first
- `Hemera/Entities/Light/UI/LightCardViewModel.swift`
- `Hemera/Entities/Light/UI/LightControlPanel.swift`
- `Hemera/Entities/Light/UI/LightCard.swift`
- `Hemera/Entities/Light/LightEntity.swift` (confirm `supportedColorModes` type, `brightness` optionality)
- `Hemera/Entities/Switch/UI/SwitchControlPanel.swift` (power-toggle reference)
- `HemeraTests/Entities/` (existing light VM test style, if any)
