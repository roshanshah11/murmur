#!/bin/bash
# Adapter: cli_transcribe
#
# Drive Murmur's headless transcription mode against a fixture WAV and assert
# matchers on the cleaned stdout transcript.
#
# Scenario JSON shape consumed:
#   {
#     "id": "...",
#     "type": "cli_transcribe",
#     "input_wav": "fixtures/02-code-comment.wav",   # relative to scenario file
#     "profile": "code" | "formal" | "casual" | "raw",
#     "language": "en" | "es" | ...,
#     "model": "ggml-base.en" | "ggml-small" | ...,
#     "vocabulary_file": "fixtures/code-vocab.json",  # optional
#     "expect_contains":     ["substring1", ...],     # all must appear
#     "expect_not_contains": ["substring2", ...],     # none may appear
#     "expect_regex":        "^// .*==",              # optional, ERE
#     "max_wall_seconds":    15                       # optional perf budget
#   }
#
# Exit codes: 0 pass, 1 fail, 2 bad invocation, 77 skip.

set -euo pipefail

SCENARIO=${1:?scenario path required}
MURMUR_APP=${2:?Murmur.app path required}

SCENARIO_DIR="$(cd "$(dirname "$SCENARIO")" && pwd)"
BIN="$MURMUR_APP/Contents/MacOS/Murmur"

if [[ ! -x "$BIN" ]]; then
  echo "skip: Murmur binary not found at $BIN" >&2
  exit 77
fi

INPUT_REL=$(jq -r '.input_wav' "$SCENARIO")
INPUT_WAV="$SCENARIO_DIR/$INPUT_REL"
if [[ ! -f "$INPUT_WAV" ]]; then
  echo "skip: fixture WAV not generated yet: $INPUT_WAV" >&2
  echo "       (see fixtures/README.md for generation steps)" >&2
  exit 77
fi

PROFILE=$(jq -r '.profile // "casual"' "$SCENARIO")
LANG=$(jq -r '.language // "en"' "$SCENARIO")
MODEL=$(jq -r '.model // "ggml-base.en"' "$SCENARIO")
VOCAB_REL=$(jq -r '.vocabulary_file // empty' "$SCENARIO")
MAX_WALL=$(jq -r '.max_wall_seconds // 30' "$SCENARIO")

ARGS=( --transcribe-only "$INPUT_WAV"
       --profile "$PROFILE"
       --language "$LANG"
       --model "$MODEL" )

if [[ -n "$VOCAB_REL" ]]; then
  ARGS+=( --vocabulary "$SCENARIO_DIR/$VOCAB_REL" )
fi

TMP_OUT=$(mktemp -t murmur_out)
TMP_ERR=$(mktemp -t murmur_err)
trap 'rm -f "$TMP_OUT" "$TMP_ERR"' EXIT

START=$(date +%s)
set +e
"$BIN" "${ARGS[@]}" >"$TMP_OUT" 2>"$TMP_ERR"
EXIT=$?
set -e
END=$(date +%s)
WALL=$(( END - START ))

if [[ $EXIT -ne 0 ]]; then
  echo "fail: Murmur exited $EXIT" >&2
  echo "----- stderr -----" >&2
  cat "$TMP_ERR" >&2
  exit 1
fi

if [[ $WALL -gt $MAX_WALL ]]; then
  echo "fail: wall time ${WALL}s exceeds budget ${MAX_WALL}s" >&2
  exit 1
fi

ACTUAL=$(cat "$TMP_OUT")

FAIL=0
FAIL_DETAIL=""

# expect_contains — all must match
while IFS= read -r needle; do
  [[ -z "$needle" ]] && continue
  if ! grep -qF -- "$needle" "$TMP_OUT"; then
    FAIL=1
    FAIL_DETAIL+=$'\n  missing substring: '"$needle"
  fi
done < <(jq -r '.expect_contains[]? // empty' "$SCENARIO")

# expect_not_contains — none may match
while IFS= read -r needle; do
  [[ -z "$needle" ]] && continue
  if grep -qF -- "$needle" "$TMP_OUT"; then
    FAIL=1
    FAIL_DETAIL+=$'\n  forbidden substring present: '"$needle"
  fi
done < <(jq -r '.expect_not_contains[]? // empty' "$SCENARIO")

# expect_regex (optional, ERE)
REGEX=$(jq -r '.expect_regex // empty' "$SCENARIO")
if [[ -n "$REGEX" ]]; then
  if ! grep -Eq -- "$REGEX" "$TMP_OUT"; then
    FAIL=1
    FAIL_DETAIL+=$'\n  regex did not match: '"$REGEX"
  fi
fi

if [[ $FAIL -ne 0 ]]; then
  {
    echo "fail: assertions failed${FAIL_DETAIL}"
    echo "----- transcript (first 500 chars) -----"
    head -c 500 "$TMP_OUT"
    echo
  } >&2
  exit 1
fi

echo "pass: ${WALL}s wall, $(wc -c <"$TMP_OUT") bytes transcribed" >&2
exit 0
