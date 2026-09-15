#!/usr/bin/env bash
# start-ios.sh — List available iOS simulators, start one (default: iPhone 17 Pro Max),
#                 or reuse an already-booted device, then launch the Flutter app.
#
# Usage:
#   ./scripts/start-ios.sh                  # interactive menu
#   ./scripts/start-ios.sh "iPhone 17 Pro"  # start by display name (exact or prefix match)
#   ./scripts/start-ios.sh --list           # list only, no launch
#   ./scripts/start-ios.sh --reuse          # use first already-booted device, no start
#
# Env:  CULLMODE=off|safe|aggressive  — polygon culling A/B override, see
#       "perf test flags" below.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# ── helpers ──────────────────────────────────────────────────────────────────

list_devices() {
  # Print a numbered list of available iPhone/iPad simulators with their
  # runtime, device id, and booted status.
  xcrun simctl list devices available | \
    grep -E 'iPhone|iPad' | \
    sed 's/^ *//' | \
    nl -v 0
}

# Returns the device id for a display name (exact or prefix match).
# If multiple matches, picks the first.  Exits on error.
resolve_device_id() {
  local wanted="$1"
  # Grab the raw simctl list, filter to matching lines, pick first.
  local line
  line=$(xcrun simctl list devices available | grep -i "$wanted" | head -n1) || true
  if [[ -z "$line" ]]; then
    echo "Error: no device matching '$wanted' found." >&2
    exit 1
  fi
  # Extract the UUID (the long hex string in parentheses).
  echo "$line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n1
}

bring_simulator_to_front() {
  # Launch Device Hub (Xcode 27+) or legacy Simulator.app (Xcode <= 16/26),
  # wait for the process to be ready, then activate it so its window comes to the front.

  local xcode_dev
  xcode_dev="$(xcode-select -p 2>/dev/null || true)"
  local dev_hub_app=""
  if [[ -n "$xcode_dev" && -d "$xcode_dev/../Applications/DeviceHub.app" ]]; then
    dev_hub_app="$xcode_dev/../Applications/DeviceHub.app"
  fi

  if [[ -z "$dev_hub_app" ]]; then
    dev_hub_app=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Devices' || kMDItemCFBundleIdentifier == 'com.apple.dt.DeviceHub'" 2>/dev/null | head -n1 || true)
  fi

  # Prefer Device Hub (Xcode 27+) if present
  if [[ -n "$dev_hub_app" ]]; then
    open "$dev_hub_app" 2>/dev/null || open -b com.apple.dt.Devices 2>/dev/null || open -a DeviceHub 2>/dev/null || true

    # Wait for DeviceHub process to appear (poll up to 15s).
    local waited=0
    while [[ $waited -lt 30 ]]; do
      if pgrep -x DeviceHub >/dev/null 2>&1; then
        break
      fi
      sleep 0.5
      waited=$((waited + 1))
    done

    sleep 1

    # Activate Device Hub to bring window to front
    osascript -e 'tell application id "com.apple.dt.Devices" to activate' 2>/dev/null || \
    osascript -e 'tell application "Device Hub" to activate' 2>/dev/null || \
    osascript -e 'tell application "DeviceHub" to activate' 2>/dev/null || true
    return 0
  fi

  # Fallback to legacy Simulator.app (Xcode <= 16/26)
  local sim_app
  sim_app=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.iphonesimulator'" 2>/dev/null | head -n1 || true)
  if [[ -n "$sim_app" ]]; then
    open -a Simulator 2>/dev/null || true

    local waited=0
    while [[ $waited -lt 30 ]]; do
      if pgrep -x Simulator >/dev/null 2>&1; then
        break
      fi
      sleep 0.5
      waited=$((waited + 1))
    done

    sleep 1

    osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
    return 0
  fi

  echo ""
  echo "⚠️  Neither Device Hub (Xcode 27+) nor Simulator.app (legacy) was found."
  echo "   The device is booted and the app is running, but there is no GUI to view it."
  echo "   Ensure Xcode is installed and active via 'xcode-select -s'."
  echo ""
  return 0
}

# ── perf test flags ─────────────────────────────────────────────────────────
# CULLMODE selects the far-side polygon occlusion-culling mode for a test run:
#   CULLMODE=off          draw every polygon (baseline for A/B)
#   CULLMODE=safe         shipped behaviour, safety margins on
#   CULLMODE=aggressive   margins off, hides some visible polygons (measure only)
# Example: CULLMODE=aggressive ./scripts/start-ios.sh --reuse
DART_DEFINES=()
if [[ -n "${CULLMODE:-}" ]]; then
  case "$CULLMODE" in
    off|safe|aggressive)
      DART_DEFINES+=(--dart-define=CULL_MODE="$CULLMODE")
      echo "Polygon culling mode: $CULLMODE" ;;
    *)
      echo "Warning: unknown CULLMODE '$CULLMODE' (expected off|safe|aggressive) - ignored." >&2 ;;
  esac
fi

# flutter run with the current --dart-define list. The ${arr[@]+...} form is needed
# because `set -u` on bash 3.2 treats an empty array as unset.
run_flutter() {
  flutter run ${DART_DEFINES[@]+"${DART_DEFINES[@]}"} -d "$1"
}

# ── main ─────────────────────────────────────────────────────────────────────

# 1. --list flag: just show devices and exit.
if [[ "${1:-}" == "--list" ]]; then
  list_devices
  exit 0
fi

# 2. --reuse flag: pick first already-booted device.
if [[ "${1:-}" == "--reuse" ]]; then
  device_id=$(xcrun simctl list devices available | grep -E 'iPhone|iPad' | grep '(Booted)' | head -n1 | \
    grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n1 || true)
  if [[ -z "$device_id" ]]; then
    echo "No booted device found. Run without --reuse to start one." >&2
    exit 1
  fi
  echo "Using already-booted device: $device_id"
  bring_simulator_to_front "$device_id"
  run_flutter "$device_id"
  exit 0
fi

# 3. Argument: device display name.
if [[ -n "${1:-}" ]]; then
  device_id=$(resolve_device_id "$1")
  if [[ -z "$device_id" ]]; then
    exit 1
  fi
  # Check if already booted.
  status=$(xcrun simctl list devices available | grep "$device_id" | grep -oE '\((Shutdown|Booted)\)' | tr -d '()')
  if [[ "$status" != "Booted" ]]; then
    echo "Starting device '$1' ($device_id)…"
    xcrun simctl boot "$device_id" 2>/dev/null || true
  fi
  bring_simulator_to_front "$device_id"
  run_flutter "$device_id"
  exit 0
fi

# 4. No argument: interactive menu.
echo "Available devices:"
echo
list_devices
echo
read -r -p "Select device number (or type a name to search): " choice

# Try as a number first.
if [[ "$choice" =~ ^[0-9]+$ ]]; then
  device_line=$(list_devices | sed -n "$((choice + 1))p")
  if [[ -z "$device_line" ]]; then
    echo "Invalid selection." >&2
    exit 1
  fi
  device_id=$(echo "$device_line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n1)
else
  device_id=$(resolve_device_id "$choice")
  if [[ -z "$device_id" ]]; then
    exit 1
  fi
fi

# Boot if needed.
status=$(xcrun simctl list devices available | grep "$device_id" | grep -oE '\((Shutdown|Booted)\)' | tr -d '()')
if [[ "$status" != "Booted" ]]; then
  display_name=$(xcrun simctl list devices available | grep "$device_id" | sed 's/ *//' | cut -d' ' -f1)
  echo "Starting device '$display_name' ($device_id)…"
  xcrun simctl boot "$device_id" 2>/dev/null || true
fi
bring_simulator_to_front "$device_id"

echo "Launching Flutter on $device_id …"
run_flutter "$device_id"
