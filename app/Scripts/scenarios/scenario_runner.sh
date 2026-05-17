#!/bin/bash
# Run a single Murmur verification scenario.
#
# Usage: scenario_runner.sh <scenario.json> [--app /path/to/Murmur.app]
#
# Exit codes (sysexits-style):
#   0  pass
#   1  fail (assertion mismatch / functional regression)
#   2  bad invocation / unknown scenario type
#   77 skip (prereqs not met — adapter cannot run unattended)
#
# Output: JSON line on stdout summarizing the run, human-readable detail on stderr.
# Parallel agents in Phase 13 aggregate the JSON lines.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <scenario.json> [--app <path>]" >&2
  exit 2
fi

SCENARIO=$1
shift || true

# Optional --app override; default points at the freshly-built Murmur.app.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MURMUR_APP="$REPO_ROOT/app/build/Murmur.app"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) MURMUR_APP="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$SCENARIO" ]]; then
  echo "scenario file not found: $SCENARIO" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq)" >&2
  exit 2
fi

TYPE=$(jq -r '.type' "$SCENARIO")
ID=$(jq -r '.id' "$SCENARIO")
SUMMARY=$(jq -r '.summary // ""' "$SCENARIO")

ADAPTERS_DIR="$SCRIPT_DIR/adapters"
START_TS=$(date +%s)

case "$TYPE" in
  cli_transcribe)
    bash "$ADAPTERS_DIR/cli_transcribe.sh" "$SCENARIO" "$MURMUR_APP"
    RC=$?
    ;;
  installer_flow)
    bash "$ADAPTERS_DIR/installer_flow.sh" "$SCENARIO" "$MURMUR_APP"
    RC=$?
    ;;
  update_path)
    bash "$ADAPTERS_DIR/update_path.sh" "$SCENARIO" "$MURMUR_APP"
    RC=$?
    ;;
  permissions_probe)
    bash "$ADAPTERS_DIR/permissions_probe.sh" "$SCENARIO" "$MURMUR_APP"
    RC=$?
    ;;
  *)
    echo "unknown scenario type: $TYPE" >&2
    exit 2
    ;;
esac

END_TS=$(date +%s)
DURATION=$(( END_TS - START_TS ))

case "$RC" in
  0)  STATUS="pass" ;;
  77) STATUS="skip" ;;
  *)  STATUS="fail" ;;
esac

# Emit a single JSON result line on stdout for aggregation.
jq -n \
  --arg id "$ID" \
  --arg type "$TYPE" \
  --arg summary "$SUMMARY" \
  --arg status "$STATUS" \
  --argjson rc "$RC" \
  --argjson duration "$DURATION" \
  '{id:$id, type:$type, summary:$summary, status:$status, exit_code:$rc, duration_seconds:$duration}'

exit "$RC"
