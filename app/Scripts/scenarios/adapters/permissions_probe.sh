#!/bin/bash
# Adapter: permissions_probe
#
# Simulates scenario #15 (Yusuf): macOS update silently revoked Accessibility
# permission. We verify that Murmur:
#   a) detects the missing permission within 200ms of attempting to record, and
#   b) surfaces an actionable banner instead of silently failing.
#
# Strategy:
#   1. Reset the Microphone (and Accessibility, if requested) TCC entries for
#      Murmur's bundle id via `tccutil reset`. This requires the user to
#      acknowledge a system prompt for tccutil itself on some macOS versions.
#   2. Probe AXIsProcessTrustedWithOptions() via osascript to confirm the reset
#      took effect (Accessibility is the one that breaks paste-via-CGEvent).
#   3. Drive Murmur with the `--diagnose-permissions` flag (added in Phase 9)
#      and assert its JSON report flags the missing entitlement.
#
# Scenario JSON shape consumed:
#   {
#     "id": "06_yusuf_perm_loss",
#     "type": "permissions_probe",
#     "bundle_id": "com.murmur.app",
#     "reset": ["Microphone", "Accessibility"],
#     "expect_flagged": ["accessibility"],
#     "max_detect_ms": 200
#   }
#
# Exit codes: 0 pass, 1 fail, 2 bad invocation, 77 skip.

set -euo pipefail

SCENARIO=${1:?scenario path required}
MURMUR_APP=${2:?Murmur.app path required}
BIN="$MURMUR_APP/Contents/MacOS/Murmur"

if [[ ! -x "$BIN" ]]; then
  echo "skip: Murmur binary not found at $BIN" >&2
  exit 77
fi

BUNDLE_ID=$(jq -r '.bundle_id // "com.murmur.app"' "$SCENARIO")
MAX_MS=$(jq -r '.max_detect_ms // 200' "$SCENARIO")

# `tccutil reset` will refuse silently if the user isn't admin; warn loudly.
if ! id -G | tr ' ' '\n' | grep -q '^80$'; then
  echo "skip: current user is not in the admin group; tccutil reset will no-op" >&2
  exit 77
fi

# 1) Reset requested TCC entries. tccutil prints to stdout on success.
while IFS= read -r service; do
  [[ -z "$service" ]] && continue
  if ! tccutil reset "$service" "$BUNDLE_ID" >/dev/null 2>&1; then
    echo "skip: tccutil reset $service $BUNDLE_ID failed (likely SIP / no prior grant)" >&2
    exit 77
  fi
done < <(jq -r '.reset[]? // empty' "$SCENARIO")

# 2) AX probe via osascript — Accessibility is the one that silently kills
#    CGEvent posting after an OS update. AXIsProcessTrustedWithOptions returns
#    a boolean; we expect FALSE immediately after reset.
AX_TRUSTED=$(osascript -e 'tell application "System Events" to UI elements enabled' 2>/dev/null || echo "false")
if [[ "$AX_TRUSTED" == "true" ]]; then
  echo "fail: Accessibility still appears granted after reset — tccutil didn't take?" >&2
  exit 1
fi

# 3) Drive Murmur's self-diagnostic mode. This flag was added so we don't have
#    to fake an `fn` double-tap headlessly. It returns a JSON report on stdout
#    and exits non-zero if any required permission is missing — that's the
#    expected behavior here.
TMP=$(mktemp -t murmur_diag)
trap 'rm -f "$TMP"' EXIT

START_NS=$(python3 -c 'import time; print(int(time.monotonic_ns()))')
set +e
"$BIN" --diagnose-permissions --json >"$TMP"
DIAG_RC=$?
set -e
END_NS=$(python3 -c 'import time; print(int(time.monotonic_ns()))')
DETECT_MS=$(( (END_NS - START_NS) / 1000000 ))

if [[ $DETECT_MS -gt $MAX_MS ]]; then
  echo "fail: permission detection took ${DETECT_MS}ms (budget ${MAX_MS}ms)" >&2
  exit 1
fi

# Expect the diagnostic to report the missing services in its .missing array.
while IFS= read -r required; do
  [[ -z "$required" ]] && continue
  if ! jq -e --arg s "$required" '.missing | index($s)' "$TMP" >/dev/null; then
    echo "fail: diagnostic did not flag missing service: $required" >&2
    echo "----- diagnostic output -----" >&2
    cat "$TMP" >&2
    exit 1
  fi
done < <(jq -r '.expect_flagged[]? // empty' "$SCENARIO")

# DIAG_RC should be nonzero because some permission is missing. If Murmur
# returned 0, it's silently OK with the broken state — that's the bug we care
# about.
if [[ $DIAG_RC -eq 0 ]]; then
  echo "fail: --diagnose-permissions exited 0 despite missing entitlement" >&2
  exit 1
fi

echo "pass: detected missing permission in ${DETECT_MS}ms" >&2
exit 0
