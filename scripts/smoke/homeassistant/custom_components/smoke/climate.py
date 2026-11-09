"""A thermostat that switches mode the moment it is asked."""

from homeassistant.components.climate import ClimateEntity, ClimateEntityFeature, HVACMode
from homeassistant.const import UnitOfTemperature

from . import THERMOSTAT_DEVICE


async def async_setup_entry(hass, entry, async_add_entities):
    async_add_entities([SmokeThermostat()])


class SmokeThermostat(ClimateEntity):
    # No area of its own, so it shows in its device's area.
    entity_id = "climate.smoke_thermostat"
    _attr_has_entity_name = True
    _attr_name = None
    _attr_unique_id = "smoke_thermostat"
    _attr_device_info = {"identifiers": {THERMOSTAT_DEVICE}}
    _attr_hvac_modes = [HVACMode.OFF, HVACMode.HEAT]
    _attr_hvac_mode = HVACMode.HEAT
    _attr_supported_features = (
        ClimateEntityFeature.TARGET_TEMPERATURE | ClimateEntityFeature.TURN_ON | ClimateEntityFeature.TURN_OFF
    )
    _attr_temperature_unit = UnitOfTemperature.CELSIUS
    _attr_current_temperature = 20.0
    _attr_target_temperature = 21.0

    async def async_set_hvac_mode(self, hvac_mode):
        self._attr_hvac_mode = hvac_mode
        self.async_write_ha_state()

    async def async_set_temperature(self, **kwargs):
        self._attr_target_temperature = kwargs["temperature"]
        self.async_write_ha_state()
