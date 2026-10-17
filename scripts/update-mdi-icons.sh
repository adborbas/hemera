#!/bin/bash
#
# Vendors the Material Design Icons webfont into Mortar.
#
# Pin to the version Home Assistant's frontend ships, not MDI's latest: matching it is what
# guarantees a glyph in Hemera is the glyph on the user's own dashboard. Check
# https://github.com/home-assistant/frontend/blob/dev/package.json for "@mdi/svg".
#
# Usage: ./scripts/update-mdi-icons.sh [mdi-version]

set -euo pipefail

MDI_VERSION="${1:-7.4.47}"
OUT_DIR="Packages/Mortar/Sources/Mortar/Resources"
EXPECTED_POSTSCRIPT_NAME="MaterialDesignIcons"

echo "@mdi version : $MDI_VERSION"
echo "destination  : $OUT_DIR"
echo

mkdir -p "$OUT_DIR"

echo "Downloading webfont..."
curl -sfL --max-time 120 \
  "https://cdn.jsdelivr.net/npm/@mdi/font@${MDI_VERSION}/fonts/materialdesignicons-webfont.ttf" \
  -o "$OUT_DIR/materialdesignicons-webfont.ttf"

echo "Downloading licence..."
curl -sfL --max-time 60 \
  "https://cdn.jsdelivr.net/npm/@mdi/font@${MDI_VERSION}/LICENSE" \
  -o "$OUT_DIR/MDI-LICENSE.txt"

echo "Building codepoint table..."
MDI_VERSION="$MDI_VERSION" OUT_DIR="$OUT_DIR" python3 -I - <<'PYEOF'
import json, os, urllib.request

version = os.environ["MDI_VERSION"]
out_dir = os.environ["OUT_DIR"]

url = f"https://cdn.jsdelivr.net/npm/@mdi/svg@{version}/meta.json"
with urllib.request.urlopen(url, timeout=120) as response:
    meta = json.load(response)

# Aliases are deliberately excluded: Home Assistant's own icon database is keyed by canonical name
# (gen-icons-json.js writes `output[icon.name]`), so resolving an alias here would draw a glyph
# where Home Assistant itself draws nothing.
codepoints = {icon["name"]: icon["codepoint"] for icon in meta}

path = os.path.join(out_dir, "MDICodepoints.json")
with open(path, "w") as f:
    json.dump({"mdiVersion": version, "codepoints": codepoints}, f, separators=(",", ":"), sort_keys=True)
    f.write("\n")

print(f"  {len(codepoints)} glyphs -> {path} ({os.path.getsize(path)/1024:.0f} KB)")
PYEOF

echo
echo "Verifying font..."
POSTSCRIPT_NAME=$(python3 -I -c "
import struct, sys
data = open('$OUT_DIR/materialdesignicons-webfont.ttf','rb').read()
count = struct.unpack('>H', data[4:6])[0]
for i in range(count):
    off = 12 + i*16
    tag = data[off:off+4]
    if tag == b'name':
        tbl = struct.unpack('>I', data[off+8:off+12])[0]
        n = struct.unpack('>H', data[tbl+2:tbl+4])[0]
        storage = tbl + struct.unpack('>H', data[tbl+4:tbl+6])[0]
        for r in range(n):
            rec = tbl + 6 + r*12
            pid, eid, lid, nid, length, offset = struct.unpack('>HHHHHH', data[rec:rec+12])
            if nid == 6:
                raw = data[storage+offset:storage+offset+length]
                print(raw.decode('utf-16-be' if pid == 3 else 'latin-1'))
                sys.exit(0)
")

echo "  PostScript name: $POSTSCRIPT_NAME"
if [ "$POSTSCRIPT_NAME" != "$EXPECTED_POSTSCRIPT_NAME" ]; then
    echo
    echo "  ERROR: expected '$EXPECTED_POSTSCRIPT_NAME'."
    echo "  MDIIconFont.fontName must be updated to match, or nothing will render."
    exit 1
fi

echo
echo "Done. $(du -h "$OUT_DIR/materialdesignicons-webfont.ttf" | cut -f1) font vendored at $MDI_VERSION."
