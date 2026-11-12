---
status: accepted
---

# The theme stores the colour, not the pick

The app has one **theme**, kept in the settings document. It is always present and carries a kind:
**None**, which stores nothing else, or **Gradient**, which stores the colour as the user saw it (hue,
saturation, brightness), an **intensity** from 0 to 1, and the **family** the colour was picked from.

The colour is the truth. The family is only a hint that lets the editor open on the page the colour
came from, because a pale colour can belong to more than one family. A missing or unknown family must
still load; the editor then shows the nearest one.

Everything that turns the stored colour into pixels is worked out when drawing and never stored: the
easing that keeps low intensities subtle, the shift that keeps cards apart from the background, and
the dimming on the screensaver.

## Considered options

- **Store the pick** (family, angle, distance from the centre). Smaller, and nothing can disagree, but
  it is a position in one particular editor. Replacing the editor would leave saved themes with no
  meaning, and retuning a family would shift colours people had chosen.
- **Store nothing when there is no theme.** The settings decoder fills missing fields from the
  defaults, which it cannot do for a value that is absent by default: the first field added to the
  theme later would reset every setting.
- **Store the painted colour.** It would freeze the card and screensaver adjustments into saved data,
  so tuning them would no longer reach existing themes.

## Consequences

Choosing None forgets the colour and intensity; the editor remembers them only while it is open.

A new kind of theme is a new kind with its own fields. A new editor reads the colour and places its
own handle at the nearest point it can show.
