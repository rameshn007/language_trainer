#!/usr/bin/env zsh
# start-ios.sh — List available iOS simulators, start one (default: iPhone 17 Pro Max),
#                 or reuse an already-booted device, then launch the Flutter app.
#
# Usage:
#   ./scripts/start-ios.sh                  # interactive menu
#   ./scripts/start-ios.sh "iPhone 17 Pro"  # start by display name (exact or prefix match)
#   ./scripts/start-ios.sh --list           # list only, no launch
#   ./scripts/start-ios.sh --reuse          # use first already-booted device, no start

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
  # Launch Simulator.app (idempotent), wait for it to be ready,
  # then activate it so its window comes to the front.
  # If Simulator.app is not installed, print a helpful message.

  local sim_app
  sim_app=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.iphonesimulator'" 2>/dev/null | head -n1)
  if [[ -z "$sim_app" ]]; then
    echo ""
    echo "⚠️  Simulator.app is not installed."
    echo "   The device is booted and the app is running, but there is no GUI to view it."
    echo "   Install the Simulator app from the Mac App Store:"
    echo "     https://apps.apple.com/us/app/simulator/id1149607702"
    echo "   Or install Xcode (not beta) which bundles Simulator."
    echo ""
    return 0
  fi

  open -a Simulator 2>/dev/null || true

  # Wait for Simulator process to appear (poll up to 15s).
  local waited=0
  while [[ $waited -lt 30 ]]; do
    if pgrep -x Simulator >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
    waited=$((waited + 1))
  done

  # Give Simulator a moment to finish its own startup.
  sleep 1

  # Activate Simulator — this should bring its window to the front.
  osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
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
  flutter run -d "$device_id"
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
  flutter run -d "$device_id"
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
flutter run -d "$device_id"
