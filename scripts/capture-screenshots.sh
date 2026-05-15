#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Hemera.xcodeproj"
SCHEME="Hemera"
OUTPUT_DIR="$PROJECT_DIR/Screenshots"
DERIVED_DATA="$PROJECT_DIR/.deriveddata-screenshots"

# Find simulator UDID for a device name, preferring the latest runtime.
# Args: DEVICE_NAME MATCH_MODE (exact|substring)
find_simulator() {
    local name="$1"
    local match_mode="${2:-exact}"
    xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
name, match_mode = sys.argv[1], sys.argv[2]
candidates = []
for runtime, devices in data['devices'].items():
    for d in devices:
        matched = (name == d['name'].strip()) if match_mode == 'exact' else (name in d['name'])
        if matched and d['isAvailable']:
            candidates.append((runtime, d['udid']))
candidates.sort(key=lambda x: x[0])
if candidates:
    print(candidates[-1][1])
" "$name" "$match_mode" 2>/dev/null || echo ""
}

IPHONE_69_ID="$(find_simulator "iPhone 16 Pro Max" "exact")"

IPAD_13_ID="$(find_simulator "iPad Pro 13-inch (M4)" "substring")"

capture_screenshots() {
    local device_name="$1"
    local device_id="$2"
    local output_subdir="$3"
    shift 3
    local test_filters=("$@")

    if [ -z "$device_id" ]; then
        echo "WARNING: No simulator found for $device_name, skipping"
        return
    fi

    echo "=== Capturing on $device_name ($device_id) ==="

    local result_bundle="$DERIVED_DATA/results-${output_subdir}.xcresult"
    rm -rf "$result_bundle"

    local testing_args=()
    if [ ${#test_filters[@]} -eq 0 ]; then
        testing_args+=("-only-testing:HemeraUITests/ScreenshotTests")
    else
        for filter in "${test_filters[@]}"; do
            testing_args+=("-only-testing:HemeraUITests/ScreenshotTests/$filter")
        done
    fi

    xcodebuild test \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$device_id" \
        "${testing_args[@]}" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$result_bundle" \
        2>&1 | tail -5

    local attachment_dir="$OUTPUT_DIR/$output_subdir"
    rm -rf "$attachment_dir"
    mkdir -p "$attachment_dir"

    xcrun xcresulttool export attachments \
        --path "$result_bundle" \
        --output-path "$attachment_dir"

    echo "Screenshots saved to $attachment_dir"
    echo ""
}

# Portrait-only tests (used for both iPhone and iPad)
PORTRAIT_TESTS=(
    "testScreenshot_01_HomeTab_Portrait"
    "testScreenshot_02_AreasTab_Portrait"
    "testScreenshot_03_LightControlPanel_Portrait"
    "testScreenshot_04_CoverControlPanel_Portrait"
    "testScreenshot_05_SwitchControlPanel_Portrait"
    "testScreenshot_06_ClimateControlPanel_Portrait"
    "testScreenshot_07_AreaDetail_Portrait"
)

# Per-device capture: dark mode portrait only
capture_device() {
    local device_name="$1"
    local device_id="$2"
    local dir_prefix="$3"
    shift 3
    local test_filters=("$@")

    if [ -z "$device_id" ]; then
        echo "WARNING: No simulator found for $device_name, skipping"
        return
    fi

    xcrun simctl boot "$device_id" 2>/dev/null || true
    xcrun simctl status_bar "$device_id" override --time "9:41"
    xcrun simctl ui "$device_id" appearance dark
    capture_screenshots "$device_name" "$device_id" "$dir_prefix" ${test_filters[@]+"${test_filters[@]}"}
}

# Clean previous output
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "=== App Store Screenshot Capture ==="
echo ""

capture_device "iPhone 16 Pro Max (6.9\")" "$IPHONE_69_ID" "iPhone-6.9-Dark" "${PORTRAIT_TESTS[@]}"
capture_device "iPad Pro 13-inch (M4)"     "$IPAD_13_ID"   "iPad-13-Dark"    "${PORTRAIT_TESTS[@]}"

echo "=== Done ==="
echo "All screenshots saved to: $OUTPUT_DIR"
ls -d "$OUTPUT_DIR"/*/
