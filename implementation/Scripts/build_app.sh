#!/usr/bin/env bash
set -euo pipefail

# Build FlowLite as an unsigned .app bundle suitable for local use.
# The bundle is required so macOS attributes Microphone / Accessibility
# / Input Monitoring permissions to a stable identity instead of the
# transient `.build/release/FlowLite` path.

cd "$(dirname "$0")/.."

echo "Building FlowLite (release)..."
if ! swift build -c release; then
  cat >&2 <<EOF

swift build failed — install full Xcode.app or run this script after a
working SwiftPM is available. The Command Line Tools toolchain alone
cannot resolve the SwiftPM manifest link step required here.

  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
EOF
  exit 2
fi

BINARY=".build/release/FlowLite"
APP_DIR="build/FlowLite.app"

if [ ! -x "$BINARY" ]; then
  echo "Build succeeded but binary not found at $BINARY" >&2
  exit 2
fi

rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "$BINARY" "${APP_DIR}/Contents/MacOS/FlowLite"
chmod +x "${APP_DIR}/Contents/MacOS/FlowLite"

cat > "${APP_DIR}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>FlowLite</string>
    <key>CFBundleDisplayName</key>
    <string>Flow Lite</string>
    <key>CFBundleIdentifier</key>
    <string>com.flowlite.app</string>
    <key>CFBundleVersion</key>
    <string>0.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>FlowLite</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Flow Lite records dictation audio locally. Audio never leaves your Mac.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Flow Lite simulates Cmd+V to paste your transcript into the active app.</string>
</dict>
</plist>
PLIST

cat <<EOF

FlowLite.app built at:
  $(pwd)/${APP_DIR}

First-run instructions:
  1. The bundle is unsigned. The first time you open it, right-click
     FlowLite.app → Open → Open (you only need to do this once).

  2. When macOS prompts, grant FlowLite:
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
