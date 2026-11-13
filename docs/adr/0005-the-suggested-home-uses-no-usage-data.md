---
status: accepted
---

# The Suggested Home uses no usage data

During **onboarding** Hemera fills Home with a **Suggested Home**: up to 12 tiles chosen from data the
first sync already brings. It takes one entity per kind per round (light, climate, cover, switch,
vacuum, action), spreads each kind across areas, and puts one tile per device. Dimmable lights and
positionable covers become medium tiles, up to four. How often anything is used plays no part.

The feature started as "the most-used entities", and Home Assistant offers nothing that answers that
well enough to build a first impression on.

## Considered options

- **Usage prediction** (`usage_prediction/common_control`). It answers only for the current time of
  day, so the same home gets a different Home in the morning and at night. It is empty for a new user
  and for a kiosk user, and thin in homes run mostly by automations.
- **Logbook and history.** Counting person-initiated changes needs a query over days of recorder
  history, favours whoever uses the dashboard over wall switches, and sees nothing in a new install.
  Attribute history can't size the tiles either: the recorder never stores a light's brightness.
- **Home Assistant favourites and `favorite` labels.** Few people set them, and those who do keep a
  handful.

Community dashboards that fill themselves in were checked. They list by area and domain, or rely on
the user's own favourites. Only Home Assistant's own frontend and widget use usage, through the same
usage prediction.

## Consequences

The Suggested Home is the same whenever it is computed, and needs no extra request or permission, so
it works for a non-admin user.

It can't tell a lamp used daily from one never touched. Area order is the registry's order, a light
group ranks below a single lamp, and a group with no area is never chosen. The user fixes these in the
Home step, which exists for that reason.

Usage data can still be added as a tie-breaker inside the same rules.
