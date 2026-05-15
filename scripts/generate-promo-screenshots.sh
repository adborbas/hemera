#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/Screenshots"
OUTPUT_DIR="$SCREENSHOTS_DIR/Promo"

# Step 1: Capture raw screenshots (dark mode, portrait only)
echo "=== Step 1: Capturing Raw Screenshots ==="
echo ""
"$PROJECT_DIR/scripts/capture-screenshots.sh"
echo ""

# Verify all expected directories exist
for dir in iPhone-6.9-Dark iPad-13-Dark; do
    if [ ! -d "$SCREENSHOTS_DIR/$dir" ]; then
        echo "ERROR: Missing raw screenshots directory: $SCREENSHOTS_DIR/$dir"
        exit 1
    fi
done

# Step 2: Download and extract Apple device bezels if needed
BEZEL_DIR="$PROJECT_DIR/Packages/AppStoreScreenshots/Resources/Bezels"
if [ ! -d "$BEZEL_DIR" ] || ! ls "$BEZEL_DIR"/*.png &>/dev/null; then
    echo "=== Step 2: Downloading Apple Device Bezels ==="
    mkdir -p "$BEZEL_DIR"

    TMPDIR_BEZELS="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR_BEZELS"' EXIT

    DMG_URL="https://devimages-cdn.apple.com/design/resources/download/Apple-Sketch-Library-Product-Bezels.dmg"
    DMG_PATH="$TMPDIR_BEZELS/bezels.dmg"
    MOUNT_PATH="$TMPDIR_BEZELS/mount"
    SKETCH_UNZIP="$TMPDIR_BEZELS/sketch"

    # Download DMG
    curl -L -o "$DMG_PATH" "$DMG_URL" 2>&1 | tail -1
    mkdir -p "$MOUNT_PATH"

    # Mount DMG (send "Y" to accept license agreement)
    echo "Y" | hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_PATH" 2>/dev/null || true

    if [ -f "$MOUNT_PATH/Apple Product Bezels.sketch" ]; then
        # Sketch files are zip archives — unzip and extract bezel PNGs
        mkdir -p "$SKETCH_UNZIP"
        unzip -q -o "$MOUNT_PATH/Apple Product Bezels.sketch" -d "$SKETCH_UNZIP"

        # Parse Sketch page JSON and extract bezel images by device name
        python3 -c "
import json, shutil, os, glob

sketch_dir = '$SKETCH_UNZIP'
bezel_dir = '$BEZEL_DIR'

page_files = glob.glob(os.path.join(sketch_dir, 'pages', '*.json'))
name_to_ref = {}
for pf in page_files:
    with open(pf) as f:
        page = json.load(f)
    for layer in page.get('layers', []):
        name = layer.get('name', '')
        for sl in layer.get('layers', []):
            ref = sl.get('image', {}).get('_ref', '')
            if ref:
                name_to_ref[name] = ref

# Devices and colors used by our screenshot configuration
targets = [
    'iPhone 16 Pro Max - Black Titanium - Portrait',
    'iPad Pro 13 (M4) - Space Gray - Portrait',
]

for target in targets:
    for layer_name, img_ref in name_to_ref.items():
        if target in layer_name:
            src = os.path.join(sketch_dir, img_ref + '.png')
            if not os.path.exists(src):
                src = os.path.join(sketch_dir, img_ref)
            dst = os.path.join(bezel_dir, target + '.png')
            if os.path.exists(src):
                shutil.copy2(src, dst)
                print(f'  Extracted: {target}.png')
            break
"
        hdiutil detach "$MOUNT_PATH" -force -quiet 2>/dev/null || true
    else
        echo "WARNING: Could not mount bezel DMG. Will use virtual bezels as fallback."
    fi

    if ls "$BEZEL_DIR"/*.png &>/dev/null; then
        echo "Device bezels ready."
    else
        echo "WARNING: No bezel images extracted. Will use virtual (programmatic) bezels."
    fi
    echo ""
fi

# Step 3: Generate framed promo screenshots
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== Step 3: Generating Framed Promo Screenshots ==="

HEMERA_PROJECT_ROOT="$PROJECT_DIR" swift test \
    --package-path "$PROJECT_DIR/Packages/AppStoreScreenshots" \
    --filter exportAllFramedScreenshots 2>&1 | tail -10

# Step 4: Resize to App Store Connect dimensions (renders are @2x)
echo ""
echo "=== Step 4: Resizing to App Store Dimensions ==="

for png in "$OUTPUT_DIR"/iPhone-6.9/*.png; do
    sips --resampleWidth 1320 "$png" --out "$png" >/dev/null
done
echo "  iPhone-6.9: 1320x2868"

for png in "$OUTPUT_DIR"/iPad-13/*.png; do
    sips --resampleWidth 2048 "$png" --out "$png" >/dev/null
done
echo "  iPad-13: 2048x2732"

echo ""
echo "=== Done ==="
echo "Promo screenshots saved to: $OUTPUT_DIR/"
for device_dir in "$OUTPUT_DIR"/*/; do
    echo ""
    echo "$(basename "$device_dir"):"
    ls "$device_dir" 2>/dev/null || echo "  (empty)"
done
