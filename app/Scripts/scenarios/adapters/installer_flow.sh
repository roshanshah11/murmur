#!/bin/bash
# Adapter: installer_flow
#
# Verifies a fresh-install experience by simulating a clean user account,
# mounting the signed DMG, dragging Murmur.app to /Applications, launching it,
# and asserting the menubar agent is alive + the binary is reachable.
#
# THIS CANNOT RUN UNATTENDED ON A NORMAL DEV BOX. It requires:
#   - sudo (to create a transient local user via `dscl`)
#   - a notarized .dmg artifact at the path provided by the scenario
#   - Accessibility prompt acknowledgment (we cannot click "Open Settings" headlessly)
#   - clean /Applications/Murmur.app slot (we move any existing install aside)
#
# If prerequisites aren't satisfied this adapter exits 77 (skip). The Phase 13
# aggregator records the skip as "manual verification owed" and does NOT block
# release on it — but ≥6 of the 8 scenarios must still pass cleanly.
#
# Scenario JSON shape consumed:
#   {
#     "id": "07_tabitha_first_launch",
#     "type": "installer_flow",
#     "dmg_path": "../../../app/build/Murmur-1.0.0.dmg",
#     "expected_bundle_id": "com.murmur.app",
#     "expected_min_version": "1.0.0",
#     "test_user": "_murmurtest"
#   }
#
# Exit codes: 0 pass, 1 fail, 2 bad invocation, 77 skip.

set -euo pipefail

SCENARIO=${1:?scenario path required}
MURMUR_APP=${2:?Murmur.app path required}   # unused here; we install from DMG
SCENARIO_DIR="$(cd "$(dirname "$SCENARIO")" && pwd)"

DMG_REL=$(jq -r '.dmg_path' "$SCENARIO")
DMG_PATH="$SCENARIO_DIR/$DMG_REL"
BUNDLE_ID=$(jq -r '.expected_bundle_id // "com.murmur.app"' "$SCENARIO")
TEST_USER=$(jq -r '.test_user // "_murmurtest"' "$SCENARIO")

# --- Prereq checks: bail early with skip(77) if we can't possibly run. -------

if [[ ! -f "$DMG_PATH" ]]; then
  echo "skip: signed DMG not present at $DMG_PATH" >&2
  echo "      (build it with app/Scripts/package_dmg.sh first)" >&2
  exit 77
fi

if ! sudo -n true 2>/dev/null; then
  echo "skip: passwordless sudo unavailable; cannot create transient test user" >&2
  echo "      manual verification owed — see phase-13-plan-amendment.md" >&2
  exit 77
fi

if [[ "${MURMUR_INSTALLER_INTERACTIVE:-0}" != "1" ]]; then
  echo "skip: interactive install requires MURMUR_INSTALLER_INTERACTIVE=1" >&2
  echo "      this run will need a human to dismiss the Gatekeeper/TCC prompts" >&2
  exit 77
fi

# --- Actual flow (gated by the env flag above). ------------------------------
# TODO(phase13): the steps below are sketched. They MUST be exercised at least
# once by a human operator before tagging v1.0.0; full automation lands in
# a follow-up CI lane that owns a dedicated mac-mini.

set -x

# 1) Park any existing install so we exercise a true fresh path.
if [[ -d /Applications/Murmur.app ]]; then
  sudo mv /Applications/Murmur.app "/Applications/Murmur.app.bak.$(date +%s)"
fi

# 2) Create transient local user (no home dir, no login shell required).
#    TODO: harden against partial-create state; idempotent teardown in trap.
sudo dscl . -create "/Users/$TEST_USER" UserShell /usr/bin/false
sudo dscl . -create "/Users/$TEST_USER" UniqueID "510"
sudo dscl . -create "/Users/$TEST_USER" PrimaryGroupID 20
sudo dscl . -create "/Users/$TEST_USER" NFSHomeDirectory "/var/empty"

cleanup() {
  set +e
  sudo dscl . -delete "/Users/$TEST_USER" 2>/dev/null
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
}
trap cleanup EXIT

# 3) Mount the DMG and copy Murmur.app into /Applications.
MOUNT_POINT=$(hdiutil attach -nobrowse -readonly "$DMG_PATH" | awk '/\/Volumes\// {print $3; exit}')
[[ -d "$MOUNT_POINT/Murmur.app" ]] || { echo "fail: DMG missing Murmur.app" >&2; exit 1; }

sudo cp -R "$MOUNT_POINT/Murmur.app" /Applications/

# 4) Gatekeeper assessment.
if ! spctl --assess --type execute /Applications/Murmur.app; then
  echo "fail: Gatekeeper rejected the installed app" >&2
  exit 1
fi

# 5) Launch and confirm the agent is running with the expected bundle id.
open -a /Applications/Murmur.app
sleep 3
if ! pgrep -f "/Applications/Murmur.app/Contents/MacOS/Murmur" >/dev/null; then
  echo "fail: Murmur process not running 3s after launch" >&2
  exit 1
fi

ACTUAL_BUNDLE=$(defaults read /Applications/Murmur.app/Contents/Info CFBundleIdentifier)
if [[ "$ACTUAL_BUNDLE" != "$BUNDLE_ID" ]]; then
  echo "fail: bundle id $ACTUAL_BUNDLE != $BUNDLE_ID" >&2
  exit 1
fi

# TODO(phase13): drive the in-app onboarding tutorial via osascript and assert
# the "Try a test recording" menu item exists — needed for scenario #16.

echo "pass: fresh install reachable and identified" >&2
exit 0
