#!/usr/bin/env bash
set -euo pipefail

# Build Murmur as an unsigned .app bundle suitable for local use.
# The bundle is required so macOS attributes Microphone / Accessibility
# / Input Monitoring permissions to a stable identity instead of the
# transient `.build/release/Murmur` path.
#
# Dependencies:
#   - Swift / SwiftPM       (Xcode.app full install)
#   - codesign / security   (built-in macOS)
#   - iconutil              (built-in macOS, used by render_icons.sh)
#   - rsvg-convert          (brew install librsvg; only required if
#                            app/Resources/AppIcon.icns is missing and
#                            needs to be regenerated from the SVG master)
#
# TODO(phase-12 signing): Sparkle's XPC services
# (Frameworks/Sparkle.framework/Versions/B/XPCServices/{Installer,Downloader}.xpc)
# and Updater.app/Autoupdate.app inside the framework must be code-signed
# inner-to-outer with a Developer ID identity before notarization. The
# current ad-hoc signing block at the bottom signs the outer bundle only,
# which is fine for local dev but will fail notarization. See
# docs/internal/sparkle-notes.md §9 pitfall #5.

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
mkdir -p "${APP_DIR}/Contents/Frameworks"

cp "$BINARY" "${APP_DIR}/Contents/MacOS/Murmur"
chmod +x "${APP_DIR}/Contents/MacOS/Murmur"

# Embed Sparkle.framework so the runtime @rpath link resolves. SwiftPM
# stages the framework next to the binary; copy it into the bundle's
# Frameworks/ dir, preserving symlinks (-a) so codesign sees a real
# versioned framework layout rather than a flattened tree.
SPARKLE_SRC=".build/release/Sparkle.framework"
if [ -d "$SPARKLE_SRC" ]; then
  cp -a "$SPARKLE_SRC" "${APP_DIR}/Contents/Frameworks/"
  # SwiftPM links Sparkle as a binary product but doesn't bake an rpath
  # pointing at the bundled Frameworks/ dir. Add one post-link so dyld
  # finds Sparkle.framework at runtime. (Suppress the "duplicate LC_RPATH"
  # warning if the script is re-run on a stale binary.)
  install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "${APP_DIR}/Contents/MacOS/Murmur" 2>/dev/null || true
else
  echo "Warning: Sparkle.framework not found at $SPARKLE_SRC — auto-updates will not work."
fi

# Copy the SwiftPM resource bundle next to the binary so Bundle.module
# resolves at runtime. SwiftPM emits `<Target>_<Target>.bundle` alongside
# the binary; we mirror that layout inside the .app's MacOS dir (which is
# where Bundle.module looks first when the bundle's executable is a CLI).
RESOURCE_BUNDLE=".build/release/Murmur_Murmur.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
  # Copy bundled JSON resources directly into Contents/Resources so
  # Bundle.main.url(forResource:withExtension:) finds them. ModelManifest.bundled()
  # tries Bundle.main first, then walks the wrapped-bundle candidates,
  # then SPM's Bundle.module accessor as a last resort. The plain
  # Contents/Resources/ layout below also keeps codesign happy without
  # the wrapped-bundle Info.plist gymnastics.
  cp -R "${RESOURCE_BUNDLE}/." "${APP_DIR}/Contents/Resources/"
else
  echo "Warning: SwiftPM resource bundle not found at $RESOURCE_BUNDLE"
fi

# Copy AppIcon.icns into the bundle. The .icns is committed under
# Resources/, but regenerate from the SVG master if missing (e.g. a
# clean clone where the developer hasn't pulled the binary).
ICON_SRC="Resources/AppIcon.icns"
if [ ! -f "$ICON_SRC" ]; then
  echo "AppIcon.icns missing — regenerating from SVG master..."
  if [ -x "Scripts/render_icons.sh" ]; then
    bash "Scripts/render_icons.sh"
  else
    echo "Warning: Scripts/render_icons.sh not found or not executable."
    echo "         Bundle will ship without an app icon."
  fi
fi
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "${APP_DIR}/Contents/Resources/AppIcon.icns"
else
  echo "Warning: $ICON_SRC still missing after render attempt — bundle has no icon."
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
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>Murmur</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
    <key>SUFeedURL</key>
    <string>https://roshanshah11.github.io/murmur/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>PLACEHOLDER_REPLACE_BEFORE_FIRST_RELEASE</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <!--
      Disable Sparkle's XPC services for ad-hoc-signed dev builds. macOS
      refuses to launch ad-hoc-signed XPC services, so the default XPC
      installer + downloader paths fail with "the updater failed to start."
      With these set to false, Sparkle uses the in-process legacy path.
      Once we have a Developer ID and a notarized build, flip both back to
      true (or remove these keys) to restore the more isolated XPC path.
    -->
    <key>SUEnableInstallerLauncherService</key>
    <false/>
    <key>SUEnableDownloaderService</key>
    <false/>
</dict>
</plist>
PLIST

# Sparkle requires inner-to-outer signing of every nested bundle — the XPC
# services + Updater.app + framework MUST be signed individually before the
# parent app. --deep alone does NOT do this correctly for Sparkle. Without
# this, "Check for updates" fails with "The updater failed to start."
SPARKLE_FW="$APP_DIR/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
  for xpc in "$SPARKLE_FW/Versions/B/XPCServices/"*.xpc; do
    [ -d "$xpc" ] || continue
    codesign --force --sign "$SIGN_ARG" --timestamp=none "$xpc"
  done
  if [ -d "$SPARKLE_FW/Versions/B/Updater.app" ]; then
    codesign --force --sign "$SIGN_ARG" --timestamp=none --deep "$SPARKLE_FW/Versions/B/Updater.app"
  fi
  codesign --force --sign "$SIGN_ARG" --timestamp=none --deep "$SPARKLE_FW"
fi

codesign --force \
  --sign "$SIGN_ARG" \
  --identifier "com.murmur.app" \
  -r '=designated => identifier "com.murmur.app"' \
  "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR" 2>&1 | tail -3 || true
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
