---
status: accepted
---

# Climate history comes from long-term statistics, not recorder history

Climate history reads every time range from Home Assistant's long-term statistics
(`recorder/statistics_during_period`) rather than from detailed recorder history. Statistics
arrive pre-aggregated, so a month-long range is hundreds of climate samples instead of tens of
thousands of states, and they outlive the recorder's purge window — which defaults to 10 days,
so a 30-day chart built on detailed history would be two-thirds empty on a stock install.

## Consequences

Home Assistant only produces long-term statistics for sensors it treats as measurements.
Integration-provided temperature and humidity sensors qualify; some hand-written template
sensors do not, and for those the climate history is legitimately empty. Hemera shows an
explicit "no recorded history" state rather than falling back to detailed recorder history,
so the gap is visible instead of silently papered over. Adding that fallback later is a small,
contained change if real homes turn out to need it.
