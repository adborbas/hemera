# Hemera

Hemera is an iOS client for Home Assistant. Its domain is a mirror of the user's home as
Home Assistant describes it, plus the user's own curation of what to show and where.

## Language

**Entity**:
A single thing Home Assistant exposes, identified by an entity ID. Hemera mirrors entities
locally and controls them through Home Assistant, never directly.

**Area**:
A grouping of entities defined on the Home Assistant side, usually a room.
_Avoid_: Room, zone, group

**Climate**:
The Home Assistant domain of thermostats and HVAC units — things with a target temperature.
Never use "climate" alone to mean the temperature and humidity of a room; that is a climate
summary or climate history.

## Climate readings

**Representative sensor**:
The single sensor chosen to speak for an area for a given measurement — the first temperature
sensor and the first humidity sensor of the area that Home Assistant does not hide. An area
with three thermometers still has one representative temperature sensor.

**Climate summary**:
An area's current temperature and humidity, as a pair, taken from its representative sensors.
_Avoid_: Climate reading, conditions

**Climate history**:
The recorded series of an area's temperature and humidity over a chosen time range, as read
back from Home Assistant. Distinct from a climate summary, which is only the present moment.

**Climate sample**:
One entry in a climate history: an interval and the mean value measured across it. A sample
covers a span of time, not an instant.
_Avoid_: History point, data point, reading, measurement

**Time range**:
The span a climate history covers, chosen by the user from a fixed set of options. Each range
implies how coarse its samples are — a longer range is made of longer samples.

**Long-term statistics**:
Home Assistant's aggregated, long-lived record of a sensor's values, retained after the
detailed recorder history for that sensor has been purged. The source of climate history.
_Avoid_: History (unqualified — ambiguous between this and detailed recorder history)
