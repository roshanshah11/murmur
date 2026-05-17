#!/usr/bin/env bash
# package_dmg.sh — Build a signed, stapled DMG for a Murmur.app bundle.
#
# Usage:
#   package_dmg.sh path/to/Murmur.app
#
# Produces, next to the input bundle:
#   Murmur-${VERSION}.dmg
#   Murmur-${VERSION}.dmg.sha256
#
# Requires `create-dmg` (Homebrew). Reuses $DEVELOPER_ID and the notary env
# vars established by sign_and_notarize.sh.

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

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "error: create-dmg not on PATH (brew install create-dmg)" >&2
  exit 127
fi

PLIST="$APP/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "error: $PLIST not found" >&2
  exit 66
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST")"
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "error: could not read CFBundleShortVersionString from $PLIST" >&2
  exit 65
fi

OUT_DIR="$(cd "$(dirname "$APP")" && pwd)"
DMG="$OUT_DIR/Murmur-${VERSION}.dmg"
SHA_FILE="${DMG}.sha256"

echo "==> Packaging $DMG (version $VERSION)"
rm -f "$DMG"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"

create-dmg \
  --volname "Murmur ${VERSION}" \
  --window-pos 200 120 \
  --window-size 600 360 \
  --icon-size 96 \
  --icon "$(basename "$APP")" 160 180 \
  --app-drop-link 440 180 \
  --hide-extension "$(basename "$APP")" \
  --no-internet-enable \
  "$DMG" \
  "$STAGING"

if [ -n "${DEVELOPER_ID:-}" ]; then
  echo "==> Signing DMG with: $DEVELOPER_ID"
  codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG"

  if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    echo "==> Notarizing DMG"
    xcrun notarytool submit "$DMG" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD" \
      --wait
    echo "==> Stapling DMG"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
  else
    echo "warn: notary env not set; skipping DMG notarization." >&2
  fi
else
  echo "warn: DEVELOPER_ID not set; skipping DMG signing." >&2
fi

echo "==> Writing SHA-256: $SHA_FILE"
( cd "$OUT_DIR" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$SHA_FILE")" )

echo "==> Done: $DMG"
echo "    $(cat "$SHA_FILE")"
