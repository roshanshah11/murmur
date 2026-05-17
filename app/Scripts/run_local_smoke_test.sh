#!/usr/bin/env bash
set -euo pipefail

# Local smoke test for Murmur.
# Runs 20 transcription iterations against a known-good WAV and
# reports success rate plus median / p95 latency.

cd "$(dirname "$0")/.."

CONFIG_PATH="${HOME}/Library/Application Support/Murmur/config.json"
SAMPLE="Resources/sample.wav"
ITERATIONS=20

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Missing config: $CONFIG_PATH"
  echo "Run Murmur once to generate it, or copy Resources/config.example.json there:"
  echo "    mkdir -p \"\$HOME/Library/Application Support/Murmur\""
  echo "    cp Resources/config.example.json \"$CONFIG_PATH\""
  exit 1
fi

if [ ! -f "$SAMPLE" ]; then
  echo "Sample WAV missing — regenerating with 'say' + 'afconvert'..."
  say -v Albert "the quick brown fox jumps over the lazy dog testing one two three" -o /tmp/flowlite_sample.aiff
  afconvert -d LEI16@16000 -c 1 -f WAVE /tmp/flowlite_sample.aiff "$SAMPLE"
  rm -f /tmp/flowlite_sample.aiff
fi

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

BIN=".build/release/Murmur"
if [ ! -x "$BIN" ]; then
  echo "Build succeeded but binary not found at $BIN" >&2
  exit 2
fi

now_ms() {
  python3 -c 'import time;print(int(time.time()*1000))'
}

declare -a LATENCIES=()
SUCCESS=0

echo "Running ${ITERATIONS} transcription iterations against ${SAMPLE}..."
for i in $(seq 1 "$ITERATIONS"); do
  START="$(now_ms)"
  if OUT="$("$BIN" --transcribe-only "$SAMPLE" 2>/dev/null)"; then
    END="$(now_ms)"
    ELAPSED=$(( END - START ))
    if [ -n "$(printf '%s' "$OUT" | tr -d '[:space:]')" ]; then
      SUCCESS=$(( SUCCESS + 1 ))
      LATENCIES+=("$ELAPSED")
      printf "  [%02d/%02d] ok    %5d ms  %s\n" "$i" "$ITERATIONS" "$ELAPSED" "$(printf '%s' "$OUT" | head -c 60)"
    else
      printf "  [%02d/%02d] FAIL  empty transcript\n" "$i" "$ITERATIONS"
    fi
  else
    printf "  [%02d/%02d] FAIL  non-zero exit\n" "$i" "$ITERATIONS"
  fi
done

if [ "${#LATENCIES[@]}" -eq 0 ]; then
  echo "iterations: ${ITERATIONS}  success: 0/${ITERATIONS}  median_ms: -  p95_ms: -"
  exit 1
fi

# Sort latencies ascending and compute median + p95.
SORTED="$(printf '%s\n' "${LATENCIES[@]}" | sort -n)"
COUNT="${#LATENCIES[@]}"

MEDIAN="$(printf '%s\n' "$SORTED" | awk -v c="$COUNT" '
  { a[NR]=$1 }
  END {
    if (c % 2 == 1) { print a[(c+1)/2] }
    else { print int((a[c/2] + a[c/2+1]) / 2) }
  }')"

# p95 = ceil(0.95 * count) index (1-based).
P95_IDX="$(python3 -c "import math;print(max(1, math.ceil(0.95*$COUNT)))")"
P95="$(printf '%s\n' "$SORTED" | awk -v idx="$P95_IDX" 'NR==idx { print; exit }')"

echo ""
echo "iterations: ${ITERATIONS}  success: ${SUCCESS}/${ITERATIONS}  median_ms: ${MEDIAN}  p95_ms: ${P95}"

if [ "$SUCCESS" -eq "$ITERATIONS" ]; then
  exit 0
else
  exit 1
fi
