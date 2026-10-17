#!/bin/bash
#
# Regenerates the bundled Home Assistant icon translations.
#
# These are the per-domain, per-device_class, per-state icon *names* Home Assistant publishes. The
# bundled copy seeds the first paint before the WebSocket answers, and is the only source demo mode
# has, since it never connects to a server. A live session replaces it with the server's own copy.
#
# Glyphs are a separate concern — see scripts/update-mdi-icons.sh.
#
# Usage: ./scripts/update-ha-icon-translations.sh [ha-core-tag]

set -euo pipefail

HA_TAG="${1:-2026.10.1}"
OUT_DIR="Hemera/HomeAssistant/Icons/Resources"

echo "Home Assistant core : $HA_TAG"
echo

mkdir -p "$OUT_DIR"

HA_TAG="$HA_TAG" OUT_DIR="$OUT_DIR" python3 -I - <<'PYEOF'
import base64, json, os, subprocess, sys

ha_tag = os.environ["HA_TAG"]
out_dir = os.environ["OUT_DIR"]

# Domains Hemera renders entity cards for. Keep in sync with
# HADataSyncService.iconTranslationDomains and step 15 of the "Adding a new entity type" checklist.
DOMAINS = ["light", "switch", "cover", "climate", "binary_sensor",
           "scene", "script", "automation", "button"]

translations = {}
for domain in DOMAINS:
    result = subprocess.run(
        ["gh", "api", f"repos/home-assistant/core/contents/homeassistant/components/{domain}/icons.json",
         "--jq", ".content", "-X", "GET", "-f", f"ref={ha_tag}"],
        capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        sys.exit(f"Failed to read {domain}/icons.json at {ha_tag}: {result.stderr.strip()}")
    component = json.loads(base64.b64decode(result.stdout.strip())).get("entity_component")
    if component:
        translations[domain] = component
    print(f"  {domain}: {'ok' if component else 'no entity_component'}")

path = os.path.join(out_dir, "BundledIconTranslations.json")
with open(path, "w") as f:
    json.dump({"haCoreVersion": ha_tag, "resources": translations}, f, indent=1, sort_keys=True)
    f.write("\n")

print(f"\n  {path} ({os.path.getsize(path)/1024:.0f} KB, {len(translations)} domains)")
print("\nRun the test suite: BundledIconsTests checks every name here resolves against the font.")
PYEOF
