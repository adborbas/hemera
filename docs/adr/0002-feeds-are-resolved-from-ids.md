---
status: accepted
---

# Feeds are resolved from IDs; the navigation screen is feed-agnostic

The main screen has no tab bar. A row of **pills** under the title switches between **feeds**: what
the screen shows (Home, Areas, all lights, one pinned area, and so on). Every feed is identified by a
**feed ID**, an opaque namespaced string such as `home`, `areas`, `domain:light` or `area:kitchen`.

The navigation screen only ever holds feed IDs. A session-scoped resolver turns an ID into the three
things the screen needs: a pill summary (title and icon, or nothing when the feed can't be shown), an
opaque view, and header actions described as data. The resolver hands each ID to a provider
registered for its namespace, so a new kind of feed is a new provider; the header, the pager and the
existing feeds don't change. Providers decide how their view is built, so a feed is not required to
be a grid.

The pill row is stored in the settings document as an ordered list of feed IDs, built-in and pinned
alike, with "absent" meaning the default row. Alongside it sits the set of built-in feeds the user
has already been offered, so a built-in added in a later release is appended to the end once, and a
built-in the user removed stays removed.

## Consequences

Feed IDs this build doesn't understand, or that don't currently resolve (a deleted area, a sync gap),
stay in the stored row and are written back unchanged; their pills are simply hidden. Pins are never
lost to a temporary failure or a downgrade.

Because a parent view cannot observe a nested scroll view's offset, each feed view reports its own
scroll position to the navigation screen through one modifier on its main scroll view. That is the
only obligation a feed has towards the screen that hosts it.

Custom, user-defined feeds fit this model as a further namespace backed by a stored definition (a
filter over domains, areas, floors, labels and entities, mirroring Home Assistant's own targets). They
are deliberately not built yet; the storage and resolver shape above already leave room for them.
