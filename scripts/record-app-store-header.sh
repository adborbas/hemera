#!/bin/bash
# Records the App Store product page header (AppStoreHeaderStage) as a seamless 30 s loop.
# Usage: scripts/record-app-store-header.sh ["Your home|live"]   (| breaks the line, "" for no caption)
# Needs ffmpeg and baguette (Homebrew); IPAD_13_ID picks the simulator.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$PROJECT_DIR/.deriveddata-screenshots"
OUTPUT_DIR="$PROJECT_DIR/Screenshots/Header"
CAPTION="${1-Your home|live}"
RAW="$DERIVED_DATA/app-store-header.mov"

for tool in ffmpeg baguette; do
    command -v "$tool" >/dev/null || { echo "ERROR: $tool not found (brew install $tool)"; exit 1; }
done

IPAD_13_ID="${IPAD_13_ID:-$(xcrun simctl list devices available -j | python3 -c "
import json, sys
for devices in json.load(sys.stdin)['devices'].values():
    for d in devices:
        if 'iPad Pro 13-inch (M5)' in d['name']:
            print(d['udid'])
" | tail -1)}"
[ -n "$IPAD_13_ID" ] || { echo "ERROR: no iPad Pro 13-inch (M5) simulator"; exit 1; }

xcodebuild build -project "$PROJECT_DIR/Hemera.xcodeproj" -scheme Hemera \
    -destination "platform=iOS Simulator,id=$IPAD_13_ID" -derivedDataPath "$DERIVED_DATA" 2>&1 | tail -1
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Hemera.app"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")

xcrun simctl boot "$IPAD_13_ID" 2>/dev/null || true
xcrun simctl bootstatus "$IPAD_13_ID" >/dev/null
xcrun simctl install "$IPAD_13_ID" "$APP"
baguette orientation --udid "$IPAD_13_ID" landscape-left
xcrun simctl terminate "$IPAD_13_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$IPAD_13_ID" "$BUNDLE_ID" -appStoreHeader -appStoreHeaderCaption "$CAPTION" \
    -AppleLocale en_US -AppleLanguages "(en)" >/dev/null

# The first loop can differ (the AC's first turn-on picks its mode); later loops repeat exactly.
sleep 35
xcrun simctl io "$IPAD_13_ID" recordVideo --codec=h264 --force "$RAW" >/dev/null 2>&1 & recorder=$!
sleep 34
kill -INT "$recorder"; wait "$recorder" || true

# Landscape 2752x2064 after auto-rotate; the 21:9 band is the middle 1180 px. 900 frames = exactly 30 s.
mkdir -p "$OUTPUT_DIR"
ffmpeg -v error -y -ss 2 -i "$RAW" -vf "crop=2752:1180:0:442,scale=3840:1646:flags=lanczos,fps=30" \
    -frames:v 900 -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -an -movflags +faststart "$OUTPUT_DIR/Live.mp4"
ffmpeg -v error -y -ss 10 -i "$OUTPUT_DIR/Live.mp4" -frames:v 1 "$OUTPUT_DIR/Live.png"

# The frame 30 s after the first must match it, or the loop jumps when it restarts (expect ~0.995).
ffmpeg -v error -y -ss 2 -i "$RAW" -vf "crop=2752:1180:0:442,fps=30,select='eq(n\,0)+eq(n\,900)'" \
    -fps_mode vfr "$DERIVED_DATA/seam-%d.png"
ffmpeg -v info -i "$DERIVED_DATA/seam-1.png" -i "$DERIVED_DATA/seam-2.png" -lavfi ssim -f null - 2>&1 \
    | grep -o "All:[0-9.]*" | sed "s/^/Seam SSIM /"
echo "Header saved to $OUTPUT_DIR/Live.mp4"
