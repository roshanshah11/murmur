#!/usr/bin/env bash
# sign_and_notarize.sh — codesign, notarize, and staple a Murmur .app bundle.
#
# Usage:
#   sign_and_notarize.sh path/to/Murmur.app
#
# Required env vars:
#   APPLE_ID                 — Apple ID used for notarytool submission
#   APPLE_TEAM_ID            — 10-char Apple Developer Team ID
#   APP_SPECIFIC_PASSWORD    — app-specific password for the Apple ID
#
# Optional env vars:
#   DEVELOPER_ID             — full Developer ID Application identity string.
#                              Falls back to the placeholder below; CI sets this
#                              from `security find-identity` output after the
#                              cert import step.

set -euo pipefail

if [ "${#}" -lt 1 ]; then
  echo "usage: $0 path/to/Murmur.app" >&2
  exit 64
fi

APP="$1"
if [ ! -d "$APP" ]; then
  echo "error: app bundle not found: $APP" >&2
  exit 66
fi

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${APP_SPECIFIC_PASSWORD:?APP_SPECIFIC_PASSWORD is required}"

DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: <name> (<team>)}"
ENTITLEMENTS="app/Resources/Murmur.entitlements"
if [ ! -f "$ENTITLEMENTS" ]; then
  # Fall back to a sibling path when invoked from a different cwd.
  ALT="$(cd "$(dirname "$0")/../Resources" 2>/dev/null && pwd)/Murmur.entitlements"
  if [ -f "$ALT" ]; then
    ENTITLEMENTS="$ALT"
  else
    echo "error: entitlements file not found: $ENTITLEMENTS" >&2
    exit 66
  fi
fi

echo "==> Codesigning $APP"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="${APP%.app}.zip"
echo "==> Zipping for notarytool: $ZIP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service (this may take several minutes)"
# Do not print the password.
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Done: $APP is signed, notarized, and stapled."
