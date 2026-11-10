---
status: accepted
---

# Device sensors are shown uncurated, paired by name

Every control panel can open its device's **Sensors** page: every sensor and binary sensor on the same
Home Assistant device, A to Z, named as Home Assistant's device page names them (the entity
registry's `name ?? original_name`). Hemera keeps no list of interesting sensors per domain, brand or
integration. The only filter is Home Assistant's own hidden flag.

One heuristic is deliberate. A percentage sensor and a time sensor whose names match once their last
two words are dropped ("Filter Life Level", "Filter Left Time") are shown as one card for that part.
When several parts share a name, they pair in entity-id order. Anything that doesn't match stays its
own card.

## Consequences

Integration naming leaks through as it is: Xiaomi's "Dust Bag Dust Bag Left Time", or two identical
"Brush Cleaner Brush" parts on one robot. The fix for a name is renaming the entity in Home Assistant,
which Hemera picks up on the next sync, not a mapping in Hemera.

Pairing can be wrong when parts share a name, since entity-id order is the only tiebreaker. A wrong
pair still shows true values, only grouped differently.
