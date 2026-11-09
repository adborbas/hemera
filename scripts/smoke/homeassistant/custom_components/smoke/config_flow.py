"""Home Assistant loads a config entry's flow, though this one only comes from the fixture."""

from homeassistant.config_entries import ConfigFlow


class SmokeConfigFlow(ConfigFlow, domain="smoke"):
    VERSION = 1
