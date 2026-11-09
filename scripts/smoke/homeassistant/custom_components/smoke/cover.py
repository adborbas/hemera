"""A blind that opens and closes the moment it is asked, starting closed."""

from homeassistant.components.cover import CoverEntity, CoverEntityFeature


async def async_setup_entry(hass, entry, async_add_entities):
    async_add_entities([SmokeBlind()])


class SmokeBlind(CoverEntity):
    _attr_name = "Smoke Blind"
    _attr_unique_id = "smoke_blind"
    _attr_supported_features = CoverEntityFeature.OPEN | CoverEntityFeature.CLOSE
    _attr_is_closed = True

    async def async_open_cover(self, **kwargs):
        self._attr_is_closed = False
        self.async_write_ha_state()

    async def async_close_cover(self, **kwargs):
        self._attr_is_closed = True
        self.async_write_ha_state()
