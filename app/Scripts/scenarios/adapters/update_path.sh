#!/bin/bash
# Adapter: update_path
#
# Verifies the Sparkle auto-update flow: a v1.0.0 instance, pointed at a local
# `file://` appcast, must discover and offer v1.0.1-test.
#
# THIS CANNOT RUN UNATTENDED on a normal dev box. It requires:
#   - two signed builds present on disk (v1.0.0 + v1.0.1-test)
#   - a local appcast.xml whose enclosure points at the v1.0.1-test .zip
#   - an EdDSA signature for the test enclosure that matches the public key
#     baked into the v1.0.0 build's Info.plist
#   - `defaults write com.murmur.app SUFeedURL file:///...` override
#   - human acknowledgment of Sparkle's "Install update and relaunch" dialog
#     (Sparkle deliberately does not expose an unattended path for safety)
#
# Skip semantics same as installer_flow.sh — counts as "manual verification
# owed", not a release blocker, but still must be exercised by a human prior
# to tagging v1.0.0.
#
# Scenario JSON shape consumed:
#   {
#     "id": "08_yusuf_update",       # if we ever wire scenario #15 here
#     "type": "update_path",
#     "old_build": "../../../app/build/Murmur-1.0.0.app",
#     "new_build": "../../../app/build/Murmur-1.0.1-test.app",
#     "appcast":   "../../../app/build/test-appcast.xml",
#     "expected_offer_version": "1.0.1-test"
#   }
#
# Exit codes: 0 pass, 1 fail, 2 bad invocation, 77 skip.

set -euo pipefail

SCENARIO=${1:?scenario path required}
MURMUR_APP=${2:?Murmur.app path required}   # ignored; old/new come from scenario
SCENARIO_DIR="$(cd "$(dirname "$SCENARIO")" && pwd)"

OLD_REL=$(jq -r '.old_build' "$SCENARIO")
NEW_REL=$(jq -r '.new_build' "$SCENARIO")
APPCAST_REL=$(jq -r '.appcast' "$SCENARIO")
EXPECT_VER=$(jq -r '.expected_offer_version' "$SCENARIO")

OLD_APP="$SCENARIO_DIR/$OLD_REL"
NEW_APP="$SCENARIO_DIR/$NEW_REL"
APPCAST="$SCENARIO_DIR/$APPCAST_REL"

for path in "$OLD_APP" "$NEW_APP" "$APPCAST"; do
  if [[ ! -e "$path" ]]; then
    echo "skip: missing required artifact: $path" >&2
    echo "      build v1.0.0 + v1.0.1-test and publish the test appcast first" >&2
    exit 77
  fi
done

if [[ "${MURMUR_UPDATE_INTERACTIVE:-0}" != "1" ]]; then
  echo "skip: Sparkle's update dialog requires a human; rerun with MURMUR_UPDATE_INTERACTIVE=1" >&2
  echo "      manual verification owed — see phase-13-plan-amendment.md" >&2
  exit 77
fi

set -x

# TODO(phase13): the steps below are sketched. They MUST be exercised at least
# once by a human operator before tagging v1.0.0.

# 1) Point the old build at the local appcast for this run only.
APPCAST_URL="file://$APPCAST"
defaults write com.murmur.app SUFeedURL -string "$APPCAST_URL"

# 2) Force Sparkle to skip its rate-limit and check immediately.
defaults write com.murmur.app SULastCheckTime -date "$(date -v-7d +"%Y-%m-%dT%H:%M:%SZ")"
defaults write com.murmur.app SUAutomaticallyUpdate -bool NO   # we want the dialog so we can assert it

# 3) Launch v1.0.0 and trigger an update check.
open -a "$OLD_APP"
sleep 3
osascript -e 'tell application "Murmur" to activate' || true
osascript -e 'tell application "System Events" to keystroke "u" using {command down, shift down}' || true

# 4) Inspect Sparkle's log for the offered version.
#    Sparkle logs to ~/Library/Logs/Murmur/Sparkle.log when SUEnableLogging=YES.
defaults write com.murmur.app SUEnableLogging -bool YES
SPARKLE_LOG="$HOME/Library/Logs/Murmur/Sparkle.log"
sleep 5

if [[ ! -f "$SPARKLE_LOG" ]]; then
  echo "fail: no Sparkle log at $SPARKLE_LOG — did v1.0.0 actually check?" >&2
  exit 1
fi

if ! grep -q "$EXPECT_VER" "$SPARKLE_LOG"; then
  echo "fail: Sparkle did not offer expected version $EXPECT_VER" >&2
  echo "----- last 40 lines of Sparkle.log -----" >&2
  tail -n 40 "$SPARKLE_LOG" >&2
  exit 1
fi

# TODO(phase13): auto-confirm the "Install and Relaunch" dialog via System
# Events, then assert /Applications/Murmur.app reports the new version. Today
# this needs a human; Sparkle 2 deliberately resists scripted confirmation.

# 5) Clean up the override so future launches use the production feed.
defaults delete com.murmur.app SUFeedURL || true

echo "pass: Sparkle offered $EXPECT_VER from local appcast" >&2
exit 0
