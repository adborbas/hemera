#!/bin/bash
# Runs the smoke flow per user on a Release build against a throwaway Home Assistant.
# HA_VERSION overrides latest. SMOKE_FIXTURE replaces the committed fixture, to prove a step can fail.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SMOKE="$ROOT/scripts/smoke"
FIXTURE="${SMOKE_FIXTURE:-$SMOKE/homeassistant}"
HA_PORT=18123
HA_URL="http://127.0.0.1:$HA_PORT"
# role, username, password, expected status from the admin-only /api/template
USERS=(
    "owner smoke-owner hemera-smoke-owner 200"
    "non-admin smoke-user hemera-smoke-user 401"
)
RUN_DIR="$ROOT/.smoke/runs/$(date +%Y%m%d-%H%M%S)"
DERIVED_DATA="$ROOT/.smoke/DerivedData"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
RUNTIME_VERSION="27.2"
XCODEBUILD=(xcodebuild -project "$ROOT/Hemera.xcodeproj" -scheme HemeraSmoke -configuration Release
    -derivedDataPath "$DERIVED_DATA")

HA_PID=""
RECORDING_PID=""
UDID=""
SIMULATOR_NAME=""
PAD_NAME="iPad"
# Set for the iPad pass, which runs only login and the regular-width steps.
ONLY_TESTING=()
VERSION="unknown"
RESULTS=""
FAILED=0
CURRENT_USER="-"
STARTED_AT=$SECONDS

record() {
    RESULTS+="$CURRENT_USER|$1|$2|${3:-}"$'\n'
    [ "$2" = "FAIL" ] && FAILED=1
    return 0
}

# Records the failing step, then stops: the EXIT trap cleans up and prints the table.
stop() {
    record "$1" FAIL "$2"
    exit 1
}

stop_process() {
    local pid="$1" signal="$2"
    kill "-$signal" "$pid" 2>/dev/null || return 0
    for _ in $(seq 1 60); do
        kill -0 "$pid" 2>/dev/null || { wait "$pid" 2>/dev/null; return 0; }
        sleep 1
    done
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
}

start_ha() {
    local dir="$1"
    local busy
    busy="$(lsof -nP -iTCP:$HA_PORT -sTCP:LISTEN 2>/dev/null)"
    [ -z "$busy" ] || stop "HA port" "$HA_PORT is already in use"
    mkdir -p "$dir/ha-config"
    cp -R "$FIXTURE/." "$dir/ha-config/"
    "$VENV/bin/hass" --config "$dir/ha-config" --log-file "$dir/home-assistant.log" >"$dir/ha-stdout.log" 2>&1 &
    HA_PID=$!
}

stop_ha() {
    [ -n "$HA_PID" ] || return 0
    stop_process "$HA_PID" TERM
    if kill -0 "$HA_PID" 2>/dev/null; then
        record "Stop Home Assistant" FAIL "pid $HA_PID still running"
    else
        record "Stop Home Assistant" PASS
    fi
    HA_PID=""
}

stop_recording() {
    [ -n "$RECORDING_PID" ] || return 0
    stop_process "$RECORDING_PID" INT
    RECORDING_PID=""
}

# Sets PREFLIGHT_OUTPUT to the user's access token, or to why login or their rights are wrong.
preflight() {
    PREFLIGHT_OUTPUT="$("$VENV/bin/python" "$SMOKE/preflight.py" --url "$HA_URL" --username "$1" --password "$2" \
        --template-status "$3" --version "$VERSION" --pid "$HA_PID" 2>&1)"
}

cleanup() {
    stop_recording
    [ -n "$UDID" ] && xcrun simctl shutdown "$UDID" >/dev/null 2>&1
    stop_ha

    echo
    echo "Home Assistant $VERSION | iPhone 17 Pro and $PAD_NAME, iOS $RUNTIME_VERSION | Release | $((SECONDS - STARTED_AT))s"
    printf '%-10s %-24s %-6s %s\n' "User" "Step" "Result" "Note"
    while IFS='|' read -r user step result note; do
        [ -n "$step" ] && printf '%-10s %-24s %-6s %s\n' "$user" "$step" "$result" "$note"
    done <<< "$RESULTS"
    echo "Artefacts: $RUN_DIR"
    exit "$FAILED"
}
trap cleanup EXIT
trap 'FAILED=1; exit 1' INT TERM

# A failure in here ends this user's run only, so the next user still gets a full pass.
run_user() {
    local label="$1" username="$2" password="$3" template_status="$4"
    local dir="$RUN_DIR/$label"
    CURRENT_USER="$label"

    start_ha "$dir"
    echo "[$label] Waiting for Home Assistant and logging in"
    if ! preflight "$username" "$password" "$template_status"; then
        record "Preflight login" FAIL "$PREFLIGHT_OUTPUT. See $dir/home-assistant.log"
        stop_ha
        return
    fi
    record "Preflight login" PASS

    local history
    if history="$("$VENV/bin/python" "$SMOKE/history.py" --url "$HA_URL" --token "$PREFLIGHT_OUTPUT" \
        sensor.smoke_temperature sensor.smoke_humidity 2>&1)"; then
        record "Seeded history" PASS
    else
        record "Seeded history" FAIL "$history"
    fi

    xcrun simctl shutdown "$UDID" >/dev/null 2>&1
    # An erase's first boot rewrites the language list, which restarts the daemon an install needs.
    if ! { xcrun simctl erase "$UDID" && xcrun simctl boot "$UDID" && xcrun simctl bootstatus "$UDID" -b >/dev/null \
        && xcrun simctl shutdown "$UDID" \
        && xcrun simctl boot "$UDID" && xcrun simctl bootstatus "$UDID" -b >/dev/null; }; then
        record "Simulator" FAIL "could not erase and boot $SIMULATOR_NAME ($UDID)"
        stop_ha
        return
    fi
    record "Simulator" PASS "erased $SIMULATOR_NAME"

    xcrun simctl io "$UDID" recordVideo --codec h264 --force "$dir/recording.mp4" >"$dir/recording.log" 2>&1 &
    RECORDING_PID=$!

    echo "[$label] Running the smoke tests"
    TEST_RUNNER_SMOKE_HA_URL="$HA_URL" \
    TEST_RUNNER_SMOKE_USERNAME="$username" \
    TEST_RUNNER_SMOKE_PASSWORD="$password" \
    TEST_RUNNER_SMOKE_HA_TOKEN="$PREFLIGHT_OUTPUT" \
    TEST_RUNNER_SMOKE_HA_VERSION="$VERSION" \
    TEST_RUNNER_SMOKE_ROLE="${label%-ipad}" \
    "${XCODEBUILD[@]}" test-without-building -destination "id=$UDID" -parallel-testing-enabled NO \
        ${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"} -resultBundlePath "$dir/results.xcresult" >"$dir/test.log" 2>&1
    local test_exit=$?

    stop_recording
    stop_ha

    local steps
    if ! steps="$(python3.14 "$SMOKE/results.py" "$dir/results.xcresult" 2>>"$dir/test.log")"; then
        record "Tests" FAIL "could not read results.xcresult, see $dir/test.log"
    elif [ -z "$steps" ]; then
        record "Tests" FAIL "no tests ran, see $dir/test.log"
    else
        while IFS='|' read -r step result; do
            record "$step" "$result"
        done <<< "$steps"
    fi
    [ "$test_exit" -eq 0 ] || record "xcodebuild" FAIL "exit $test_exit, see $dir/test.log"

    local missing=""
    for artefact in results.xcresult recording.mp4 home-assistant.log; do
        [ -s "$dir/$artefact" ] || [ -d "$dir/$artefact" ] || missing+=" $artefact"
    done
    if [ -n "$missing" ]; then record "Artefacts" FAIL "missing:$missing"; else record "Artefacts" PASS; fi
}

mkdir -p "$RUN_DIR"

# Home Assistant

command -v python3.14 >/dev/null || stop "Python" "python3.14 not found, Home Assistant needs 3.14.2 or newer"

if [ -n "${HA_VERSION:-}" ]; then
    VERSION="$HA_VERSION"
    record "HA version" PASS "$VERSION (HA_VERSION override)"
else
    VERSION="$(python3.14 -c "
import json, urllib.request
print(json.load(urllib.request.urlopen('https://pypi.org/pypi/homeassistant/json', timeout=30))['info']['version'])
" 2>"$RUN_DIR/version-lookup.log")" \
        || { VERSION="unknown"; stop "HA version" "PyPI lookup failed, set HA_VERSION to choose one by hand. See $RUN_DIR/version-lookup.log"; }
    record "HA version" PASS "$VERSION (latest on PyPI)"
fi

VENV="${XDG_CACHE_HOME:-$HOME/.cache}/hemera-smoke/ha-$VERSION"
if [ ! -f "$VENV/.installed" ]; then
    echo "Installing Home Assistant $VERSION into $VENV"
    python3.14 -m venv --clear "$VENV" \
        && "$VENV/bin/python" -m pip install --quiet "homeassistant==$VERSION" >"$RUN_DIR/ha-install.log" 2>&1 \
        && touch "$VENV/.installed" \
        || stop "HA install" "See $RUN_DIR/ha-install.log"
fi
record "HA install" PASS

# Every user logs in before the build, so a broken server or fixture never waits for a compile.
echo "Waiting for Home Assistant and logging in every user"
start_ha "$RUN_DIR/preflight"
READY_USERS=()
for entry in "${USERS[@]}"; do
    read -r label username password template_status <<< "$entry"
    CURRENT_USER="$label"
    if preflight "$username" "$password" "$template_status"; then
        record "Preflight login" PASS
        READY_USERS+=("$entry")
    else
        record "Preflight login" FAIL "$PREFLIGHT_OUTPUT. See $RUN_DIR/preflight/home-assistant.log"
    fi
done
CURRENT_USER="-"
stop_ha
[ "${#READY_USERS[@]}" -gt 0 ] || exit 1

# Simulator

TAG="$(git -C "$ROOT" rev-parse --show-toplevel | shasum | cut -c1-10)"

# Prints the UDID of the tagged simulator, creating it the first time.
simulator() {
    local name="$1" device_type="$2" runtime="$3" udid
    udid="$(xcrun simctl list devices -j | python3.14 -c "
import json, sys
for d in json.load(sys.stdin)['devices'].get('$runtime', []):
    if d['name'] == '$name' and d['isAvailable']:
        print(d['udid'])
        break
")"
    [ -n "$udid" ] || udid="$(xcrun simctl create "$name" "$device_type" "$runtime")" || return 1
    echo "$udid"
}

# One iOS 27.2 runtime only supports iPhone Duo, so the runtime is chosen by what it can run.
RUNTIME="$(xcrun simctl list runtimes -j | python3.14 -c "
import json, sys
for r in json.load(sys.stdin)['runtimes']:
    if r['isAvailable'] and r['version'] == '$RUNTIME_VERSION' and any(
            d['identifier'] == '$DEVICE_TYPE' for d in r['supportedDeviceTypes']):
        print(r['identifier'])
        break
")"
[ -n "$RUNTIME" ] || stop "Simulator" "no iOS $RUNTIME_VERSION runtime supports iPhone 17 Pro"
SIMULATOR_NAME="pw-$TAG-iPhone17Pro"
UDID="$(simulator "$SIMULATOR_NAME" "$DEVICE_TYPE" "$RUNTIME")" || stop "Simulator" "could not create $SIMULATOR_NAME"
record "Simulator" PASS "$SIMULATOR_NAME"

# The newest iPad is the one released for the latest runtime; a tie goes to the runtime's first listed.
PAD="$(python3.14 -c "
import json, subprocess
def simctl(kind):
    return json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', kind, '-j']))[kind]
released = {d['identifier']: d['minRuntimeVersion'] for d in simctl('devicetypes')}
pads = [(r['identifier'], d) for r in simctl('runtimes') if r['isAvailable'] and r['version'] == '$RUNTIME_VERSION'
        for d in r['supportedDeviceTypes'] if d['productFamily'] == 'iPad']
runtime, pad = max(pads, key=lambda p: released[p[1]['identifier']])
print(runtime, pad['identifier'], pad['name'])
" 2>/dev/null)"
read -r PAD_RUNTIME PAD_TYPE PAD_NAME <<< "$PAD"
[ -n "$PAD" ] || stop "Simulator" "no iOS $RUNTIME_VERSION runtime supports an iPad"
PAD_SIMULATOR_NAME="pw-$TAG-$(tr -d ' ()' <<< "$PAD_NAME")"
PAD_UDID="$(simulator "$PAD_SIMULATOR_NAME" "$PAD_TYPE" "$PAD_RUNTIME")" \
    || stop "Simulator" "could not create $PAD_SIMULATOR_NAME"
record "Simulator" PASS "$PAD_SIMULATOR_NAME"

# Build and test

echo "Building Release"
"${XCODEBUILD[@]}" build-for-testing -destination "id=$UDID" >"$RUN_DIR/build.log" 2>&1 \
    || stop "Release build" "See $RUN_DIR/build.log"
[ -d "$DERIVED_DATA/Build/Products/Release-iphonesimulator/Hemera.app" ] \
    || stop "Release build" "no Release app in $DERIVED_DATA"
record "Release build" PASS

for entry in "${READY_USERS[@]}"; do
    read -r label username password template_status <<< "$entry"
    run_user "$label" "$username" "$password" "$template_status"
done

# Navigation doesn't differ by user, so only the owner gets an iPad pass.
for entry in "${READY_USERS[@]}"; do
    read -r label username password template_status <<< "$entry"
    [ "$label" = "owner" ] || continue
    xcrun simctl shutdown "$UDID" >/dev/null 2>&1
    UDID="$PAD_UDID"
    SIMULATOR_NAME="$PAD_SIMULATOR_NAME"
    for step in testSmoke_01_Login testSmoke_21_PadPillNavigation testSmoke_22_PadAccountOpensSettings; do
        ONLY_TESTING+=("-only-testing:HemeraSmokeTests/SmokeTests/$step")
    done
    run_user "owner-ipad" "$username" "$password" "$template_status"
done
