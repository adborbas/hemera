# Hemera

Hemera is a Home Assistant client for iOS. This glossary fixes the words the project uses for its own concepts.

## Language

### Theme

**Theme**:
The look the user chooses for the app's background. There is always exactly one, shared by the whole app, and it has a kind.
_Avoid_: Skin, appearance, wallpaper

**None**:
The kind of theme that changes nothing: the app looks as it does without theming. It carries no colour or intensity.
_Avoid_: Off, disabled theme, default theme

**Gradient**:
The kind of theme that paints a soft gradient from one colour the user picked, at an intensity the user set.
_Avoid_: Colour theme, mesh

**Intensity**:
How strongly a Gradient theme colours the background, from the subtlest the app allows to the strongest.
_Avoid_: Opacity, strength, alpha

**Family**:
A group of colours that share a character: bright, pastel, muted or greyscale. It records how a colour was picked; the colour itself is what the theme keeps.
_Avoid_: Palette, page, category

**Preset**:
A ready-made colour offered in the theme editor. Choosing one is the same as picking that colour by hand.
_Avoid_: Template, swatch

### Onboarding

**Onboarding**:
The guided setup between logging in and using the app: choosing a server, logging in, arranging Home and choosing a theme. Every login that starts from the Welcome screen goes through it, a first one or a later one. Logging back in after a session expired is not onboarding.
_Avoid_: Setup wizard, first run, tutorial

**Welcome screen**:
The screen anyone who isn't logged in sees first. It leads into onboarding and is not one of its steps.
_Avoid_: Landing, splash, intro

**Step**:
One of onboarding's four stages: Server, Log in, Home and Theme.
_Avoid_: Page, stage

**Suggested Home**:
The tiles Hemera puts on Home during onboarding, chosen from the server's supported devices. The user edits it in the Home step.
_Avoid_: Prefill, pick, most-used

### Demo

**Demo mode**:
The app running on made-up data with no server. It is reachable only for App Store review and the screenshot tests.
_Avoid_: Try demo, preview

### Kiosk Mode

**Screensaver**:
The dark clock screen that replaces the app after a period of inactivity in Kiosk Mode. Any touch dismisses it.
_Avoid_: Dim screen, dim overlay, dimmed screen
