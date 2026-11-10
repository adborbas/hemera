---
status: accepted
---

# Device sensors are shown uncurated

Every control panel can open its device's **Sensors** page: every sensor and binary sensor on the same
Home Assistant device, one card each, A to Z, named as Home Assistant's device page names them (the
entity registry's `name ?? original_name`). Hemera keeps no list of interesting sensors per domain,
brand or integration, and doesn't group related sensors. The only filter is Home Assistant's own
hidden flag.

Grouping was tried and dropped: pairing a part's life percentage with its time left, battery with
charging, power with energy. Each rule was a guess about which sensors belong together, and integrations
that give two parts the same name made the guesses ambiguous.

## Consequences

Integration naming leaks through as it is: Xiaomi's "Dust Bag Dust Bag Left Time", or two identical
"Brush Cleaner Brush" parts on one robot. The fix for a name is renaming the entity in Home Assistant,
which Hemera picks up on the next sync, not a mapping in Hemera.

Related readings sit next to each other only when their names sort together.
