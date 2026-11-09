"""Entities templates can't make, a device whose area its thermostat inherits, and climate history."""

import math
from datetime import timedelta

from homeassistant.components.recorder import get_instance
from homeassistant.components.recorder.db_schema import Statistics, StatisticsShortTerm
from homeassistant.components.recorder.models import StatisticMeanType
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.helpers import device_registry as dr
from homeassistant.util import dt as dt_util

DOMAIN = "smoke"
THERMOSTAT_DEVICE = (DOMAIN, "thermostat")

# statistic id, unit, unit class, newest 5-minute mean, daily swing. The newest means are the states.
HISTORY = [
    ("sensor.smoke_temperature", "°C", "temperature", 21.5, 1.5),
    ("sensor.smoke_humidity", "%", None, 48.0, 5.0),
]
# Hourly means trail the 5-minute ones, so a chart's newest reading shows which table it came from.
HOURLY_OFFSET = -0.5


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    registry = dr.async_get(hass)
    device = registry.async_get_or_create(
        config_entry_id=entry.entry_id, identifiers={THERMOSTAT_DEVICE}, name="Smoke Thermostat"
    )
    registry.async_update_device(device.id, area_id="smoke_bedroom")
    seed_history(hass)
    await hass.config_entries.async_forward_entry_setups(entry, [Platform.CLIMATE, Platform.COVER])
    return True


def seed_history(hass: HomeAssistant) -> None:
    """
    Queues 24 hours of 5-minute and 30 days of hourly means, both ending at the top of this hour.
    The recorder's own import, because the public one and recorder/import_statistics only write hourly.
    """
    end = dt_util.utcnow().replace(minute=0, second=0, microsecond=0)
    recorder = get_instance(hass)
    for statistic_id, unit, unit_class, newest, swing in HISTORY:
        metadata = {
            "mean_type": StatisticMeanType.ARITHMETIC, "has_sum": False, "name": None, "source": "recorder",
            "statistic_id": statistic_id, "unit_class": unit_class, "unit_of_measurement": unit,
        }
        for table, step, count, last in (
            (StatisticsShortTerm, timedelta(minutes=5), 288, newest),
            (Statistics, timedelta(hours=1), 720, newest + HOURLY_OFFSET),
        ):
            stats = []
            for age in range(count):
                mean = round(last + swing * math.sin(2 * math.pi * (age * step / timedelta(days=1))), 1)
                stats.append({"start": end - step * (age + 1), "mean": mean, "min": mean, "max": mean})
            recorder.async_import_statistics(metadata, stats, table)
