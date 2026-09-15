#!/usr/bin/env zsh
set -euo pipefail

# deploy-build-ios.sh — Increment build number, build IPA, and upload to App Store Connect.
#
# Prerequisites:
#   1. Create an API key in App Store Connect (Users and Access → API Keys).
#      Download the .p8 key file and note the Key ID and Issuer ID.
#   2. Place the .p8 file somewhere accessible (e.g. ~/.auth_keys/AuthKey_XXXXXXX.p8).
#
# Usage:
#   ./scripts/deploy-build-ios.sh
#
# Environment variables:
#   ASC_API_KEY_PATH   — path to the .p8 key file (required)
#   ASC_API_KEY_ID     — App Store Connect API Key ID (required)
#   ASC_API_ISSUER_ID  — App Store Connect API Issuer ID (required)
#   XCODE_PATH         — optional path to a stable (non-beta) Xcode.app
#                        e.g. /Applications/Xcode.app
#                        If unset, defaults to /Applications/Xcode.app
#   ALLOW_BETA_XCODE   — set to 1 to bypass the beta Xcode check (optional)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# ── configuration ────────────────────────────────────────────────────────────

ASC_API_KEY_PATH="${ASC_API_KEY_PATH:?}"
API_KEY_ID="${ASC_API_KEY_ID:?}"
API_ISSUER_ID="${ASC_API_ISSUER_ID:?}"

# ── helpers ──────────────────────────────────────────────────────────────────

die() {
  echo "❌ $*" >&2
  exit 1
}

# ── verify Xcode is a released (non-beta) version ────────────────────────────

# App Store Connect requires a released (non-beta) Xcode/SDK for uploads.
# See: https://developer.apple.com/news/releases/

XCODE_PATH="${XCODE_PATH:-/Applications/Xcode.app}"

# If a custom XCODE_PATH is provided, switch to it
if [[ -d "$XCODE_PATH" ]]; then
  CURRENT_XCODE=$(xcode-select -p)
  if [[ "$CURRENT_XCODE" != "$XCODE_PATH/Contents/Developer" ]]; then
    echo "🔄 Switching Xcode developer directory to: $XCODE_PATH"
    if sudo xcode-select -s "$XCODE_PATH"; then
      : # success
    else
      die "Failed to switch Xcode developer directory.
Make sure $XCODE_PATH exists and is a released (non-beta) Xcode.app.
You can also run manually: sudo xcode-select -s $XCODE_PATH"
    fi
  fi
fi

# Verify we're not using a beta Xcode
XCODE_INFO=$(xcodebuild -version 2>&1) || die "Failed to run xcodebuild"
XCODE_VERSION=$(echo "$XCODE_INFO" | head -n1 | awk '{print $2}')
BUILD_VERSION=$(echo "$XCODE_INFO" | head -n2 | tail -n1 | awk '{print $3}')

if [[ "${ALLOW_BETA_XCODE:-0}" == "1" || "${SKIP_BETA_CHECK:-0}" == "1" ]]; then
  echo "⚠️  Bypassing Xcode beta check (ALLOW_BETA_XCODE=1)"
else
  # Apple beta build numbers use 4+ digits before trailing letter (e.g. 27A5194q, 15A5070d).
  # Official release candidate and final release builds use 1-3 digits (e.g. 27A266a, 16A242d, 15A240d)
  # or no trailing letter (e.g. 15C65).
  if [[ "$XCODE_INFO" =~ [Bb]eta ]] || [[ "$XCODE_PATH" =~ [Bb]eta ]] || [[ "$BUILD_VERSION" =~ [A-Z][0-9]{4,}[a-zA-Z]$ ]]; then
    die "Beta Xcode detected (Xcode $XCODE_VERSION, build $BUILD_VERSION).
App Store Connect requires a released or release-candidate (non-beta) Xcode version.

To fix:
  1. Install a released Xcode from: https://developer.apple.com/download/
     (requires an Apple Developer account)
  2. Place it at /Applications/Xcode.app (or set XCODE_PATH env var)
  3. Re-run this script (or set ALLOW_BETA_XCODE=1 to override)

Current Xcode: $XCODE_PATH
Build version: $BUILD_VERSION"
  fi
fi

echo "✅ Xcode $XCODE_VERSION (build $BUILD_VERSION) — release/RC version confirmed"

# ── main ─────────────────────────────────────────────────────────────────────

echo "🔨 Deploying iOS release (build + IPA + upload)..."
echo ""

# 1. Increment build number
echo "📦 Incrementing build number..."
python3 "$SCRIPT_DIR/increment_build.py" || die "Failed to increment build number"
echo ""

# 2. Build IPA
echo "🚀 Building IPA (flutter build ipa --release)..."
flutter build ipa --release || die "IPA build failed"
echo ""

# 3. Find the built IPA
IPA_PATH=$(find build/ios/ipa -name '*.ipa' -type f | head -n1)
if [[ -z "$IPA_PATH" ]]; then
  die "No .ipa file found in build/ios/ipa/"
fi

echo "📤 Uploading $IPA_PATH to App Store Connect..."
xcrun altool --upload-app \
  --type ios \
  -f "$IPA_PATH" \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID" \
  --p8-file-path "$ASC_API_KEY_PATH" \
  || die "Upload to App Store Connect failed"

echo ""
echo "✅ Done! IPA uploaded successfully."
echo "   File: $IPA_PATH"
