#!/usr/bin/env bash
set -euo pipefail

# Build Murmur as an unsigned .app bundle suitable for local use.
# The bundle is required so macOS attributes Microphone / Accessibility
# / Input Monitoring permissions to a stable identity instead of the
# transient `.build/release/Murmur` path.

cd "$(dirname "$0")/.."

echo "Building Murmur (release)..."
if ! swift build -c release; then
  cat >&2 <<EOF

swift build failed — install full Xcode.app or run this script after a
working SwiftPM is available. The Command Line Tools toolchain alone
cannot resolve the SwiftPM manifest link step required here.

  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
EOF
  exit 2
fi

BINARY=".build/release/Murmur"
APP_DIR="build/Murmur.app"

if [ ! -x "$BINARY" ]; then
  echo "Build succeeded but binary not found at $BINARY" >&2
  exit 2
fi

rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "$BINARY" "${APP_DIR}/Contents/MacOS/Murmur"
chmod +x "${APP_DIR}/Contents/MacOS/Murmur"

# Copy the SwiftPM resource bundle next to the binary so Bundle.module
# resolves at runtime. SwiftPM emits `<Target>_<Target>.bundle` alongside
# the binary; we mirror that layout inside the .app's MacOS dir (which is
# where Bundle.module looks first when the bundle's executable is a CLI).
RESOURCE_BUNDLE=".build/release/Murmur_Murmur.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  # Bundle.module looks for `<Target>_<Target>.bundle` next to the executable.
  # The bundle SPM emits is a flat dir without Info.plist, which codesign
  # rejects — so we wrap it in a minimal macOS bundle layout (Contents/
  # Resources/ + Info.plist) which both Bundle.module and codesign accept.
  WRAPPED_BUNDLE="${APP_DIR}/Contents/MacOS/Murmur_Murmur.bundle"
  mkdir -p "${WRAPPED_BUNDLE}/Contents/Resources"
  cp -R "${RESOURCE_BUNDLE}/." "${WRAPPED_BUNDLE}/Contents/Resources/"
  cat > "${WRAPPED_BUNDLE}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.murmur.resources</string>
    <key>CFBundleName</key>
    <string>Murmur_Murmur</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
PLIST
  # Also stash a flat copy under Contents/Resources for the Bundle.main fallback.
  if [ -f "${RESOURCE_BUNDLE}/model-manifest.json" ]; then
    cp "${RESOURCE_BUNDLE}/model-manifest.json" "${APP_DIR}/Contents/Resources/"
  fi
else
  echo "Warning: SwiftPM resource bundle not found at $RESOURCE_BUNDLE"
fi

# Sign with a stable identity so macOS TCC (Accessibility / Input
# Monitoring / Microphone) treats every rebuild as the same app.
# Falls back to ad-hoc if the local signer is missing; in that case
# you'll need to re-grant Accessibility after each rebuild.
SIGN_IDENTITY="Murmur Local Signer"
if security find-certificate -c "$SIGN_IDENTITY" >/dev/null 2>&1; then
  SIGN_ARG="$SIGN_IDENTITY"
  echo "Signing with identity: $SIGN_IDENTITY"
else
  SIGN_ARG="-"
  echo "Warning: '$SIGN_IDENTITY' not in keychain; falling back to ad-hoc."
  echo "         TCC permissions (Accessibility etc.) will be invalidated on every rebuild."
  echo "         Run Scripts/setup_signing.sh once to create a stable local signer."
fi

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Murmur</string>
    <key>CFBundleDisplayName</key>
    <string>Murmur</string>
    <key>CFBundleIdentifier</key>
    <string>com.murmur.app</string>
    <key>CFBundleVersion</key>
    <string>0.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>Murmur</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Murmur records dictation audio locally. Audio never leaves your Mac.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Murmur simulates Cmd+V to paste your transcript into the active app.</string>
</dict>
</plist>
PLIST

codesign --force --deep \
  --sign "$SIGN_ARG" \
  --identifier "com.murmur.app" \
  -r '=designated => identifier "com.murmur.app"' \
  "$APP_DIR"
codesign -dvv "$APP_DIR" 2>&1 | grep -E "^(Authority|Identifier)" || true

# Install to /Applications so the app is launchable from Spotlight / Launchpad
# and lives at a stable path that other tooling (TCC, mds) expects.
INSTALL_DIR="${MURMUR_INSTALL_DIR:-/Applications}"
INSTALLED_APP="${INSTALL_DIR}/Murmur.app"
if [ -w "$INSTALL_DIR" ] || [ -w "$INSTALLED_APP" ] 2>/dev/null; then
  echo "Installing to ${INSTALLED_APP}..."
  # Quit any running copy so we can overwrite without permission errors.
  pkill -f "${INSTALLED_APP}/Contents/MacOS/Murmur" 2>/dev/null || true
  sleep 1
  rm -rf "$INSTALLED_APP"
  cp -R "$APP_DIR" "$INSTALLED_APP"
  # Kick Spotlight so it shows up immediately.
  mdimport "$INSTALLED_APP" >/dev/null 2>&1 || true
  INSTALLED_OK=1
else
  echo "Note: ${INSTALL_DIR} not writable; skipping install."
  echo "      Run manually: sudo cp -R \"$APP_DIR\" \"$INSTALLED_APP\""
  INSTALLED_OK=0
fi

cat <<EOF

Murmur.app built at:
  $(pwd)/${APP_DIR}
$( [ "$INSTALLED_OK" = 1 ] && echo "Installed to:
  ${INSTALLED_APP}
You can now launch it from Spotlight (Cmd+Space → 'Murmur') or Launchpad." )

First-run instructions:
  1. The bundle is unsigned. The first time you open it, right-click
     Murmur.app → Open → Open (you only need to do this once).

  2. When macOS prompts, grant Murmur:
       • Microphone        — for audio capture
       • Accessibility     — for Cmd+V paste simulation
       • Input Monitoring  — for the global fn double-tap hotkey
     (System Settings → Privacy & Security → ... )

  3. Disable Apple's built-in Dictation so it doesn't steal the fn key:
       System Settings → Keyboard → Dictation shortcut → Off.

  4. Trigger dictation by double-tapping the fn key. Speak, then
     double-tap fn again (or pause) to stop, and the transcript will
     paste into the active app.
EOF
