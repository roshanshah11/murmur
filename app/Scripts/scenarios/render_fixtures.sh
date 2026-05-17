#!/usr/bin/env bash
#
# render_fixtures.sh — Phase 13 fixture WAV generator.
#
# Re-renders every scenario fixture WAV from text using macOS `say` and
# `afconvert`. Output format matches whisper.cpp's preferred input:
#   16 kHz / 16-bit signed little-endian / mono PCM WAV.
#
# Idempotent. Run from anywhere; resolves paths relative to this script.
#
# Skips scenarios 06 (permissions_probe) and 07 (installer_flow) — they
# have no audio component.
#
# If a requested voice is unavailable on the host macOS install, we fall
# back to a sensible default (Samantha for en, Mónica for es) and emit a
# warning. We never fail the whole job for a missing voice.
#
# Usage:
#   ./render_fixtures.sh           # render all fixtures
#   ./render_fixtures.sh --check   # verify only, do not (re)render
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures"
TMP_DIR="$(mktemp -d -t murmur-fixtures.XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

MAX_BYTES_PER_FILE=$((500 * 1024))     # 500 KB per fixture
MAX_BYTES_TOTAL=$((3 * 1024 * 1024))   # 3 MB total

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
fi

mkdir -p "${FIXTURES_DIR}"

log()  { printf '[render] %s\n' "$*" >&2; }
warn() { printf '[render][warn] %s\n' "$*" >&2; }

# Resolve a voice, falling back if unavailable.
#   $1: preferred voice
#   $2: fallback voice
# Echoes the voice that should actually be used.
resolve_voice() {
  local preferred="$1"
  local fallback="$2"
  if say -v '?' 2>/dev/null | awk '{print $1}' | grep -qx "${preferred}"; then
    printf '%s' "${preferred}"
  else
    warn "voice '${preferred}' unavailable; falling back to '${fallback}'"
    printf '%s' "${fallback}"
  fi
}

# render_one <name> <voice> <fallback> <phrase>
render_one() {
  local name="$1"
  local voice_pref="$2"
  local voice_fallback="$3"
  local phrase="$4"
  local voice
  voice="$(resolve_voice "${voice_pref}" "${voice_fallback}")"

  local aiff="${TMP_DIR}/${name}.aiff"
  local wav="${FIXTURES_DIR}/${name}.wav"

  if [[ "${CHECK_ONLY}" -eq 1 ]]; then
    if [[ ! -f "${wav}" ]]; then
      warn "missing: ${wav}"
      return
    fi
  else
    log "rendering ${name}.wav (voice=${voice})"
    say -v "${voice}" -o "${aiff}" "${phrase}"
    afconvert -f WAVE -d LEI16@16000 -c 1 "${aiff}" "${wav}" >/dev/null
  fi

  # Verify
  local info
  info="$(afinfo "${wav}" 2>/dev/null || true)"
  if ! grep -q '16000 Hz' <<<"${info}"; then
    warn "${name}.wav: not 16000 Hz"
  fi
  if ! grep -qE '(1 ch|Num Channels: *1|Channels: *1)' <<<"${info}"; then
    warn "${name}.wav: not mono"
  fi
  local size
  size=$(stat -f%z "${wav}" 2>/dev/null || stat -c%s "${wav}")
  if (( size > MAX_BYTES_PER_FILE )); then
    warn "${name}.wav exceeds 500 KB (${size} bytes)"
  fi
}

# ---------------------------------------------------------------------------
# Fixture definitions
# ---------------------------------------------------------------------------

# 01 — Devraj — code profile (Daniel, en_GB)
render_one \
  "01-devraj-code-comment" \
  "Daniel" \
  "Samantha" \
  "Refactor the auth middleware to short circuit when the J W T E X P claim is null, return four oh one with code auth underscore E X P underscore missing, and add a unit test covering the null path."

# 02 — Priya — formal/legal (Samantha, en_US)
render_one \
  "02-priya-motion" \
  "Samantha" \
  "Samantha" \
  "Plaintiff's claim fails as a matter of law under rule twelve b six because the complaint does not meet the Iqbal Twombly pleading standard, and the doctrine of in pari delicto and res judicata both bar relief."

# 03 — Jordan — AirPods routing guard (casual, en_US)
# README doesn't pin a voice for 03; use Samantha as the default en_US voice.
render_one \
  "03-jordan-airpods" \
  "Samantha" \
  "Samantha" \
  "Idea for OS final project: build a tiny scheduler that uses CFS but adds a fairness boost for IO bound threads."

# 04 — Tomás — Spanish (Paulina, es_MX)
render_one \
  "04-tomas-linkedin" \
  "Paulina" \
  "Mónica" \
  "Hoy lanzamos la nueva campaña de retención con Talento+. Estoy muy orgulloso del equipo y los OKR están en buen camino."

# 05 — Eun-ji — noisy coffee shop (Karen, en_AU)
# NOTE: README calls for sox-mixing a freesound.org coffee-shop bed onto the
# voice. We don't bundle copyrighted audio; this fixture is voice-only and
# documented as a substitution in fixtures/README.md.
render_one \
  "05-eunji-coffee-shop" \
  "Karen" \
  "Samantha" \
  "Source claims the contract was signed before the audit was completed."

# 06 — Yusuf — permissions_probe; NO WAV
# 07 — Tabitha — installer_flow;  NO WAV

# 08 — Sam — history search (Alex preferred, en_US; substitute Samantha)
render_one \
  "08-sam-q3-hiring" \
  "Alex" \
  "Samantha" \
  "Reminder to revise the Q3 hiring plan before Friday's leadership review."

# ---------------------------------------------------------------------------
# Total size guard
# ---------------------------------------------------------------------------

total=$(find "${FIXTURES_DIR}" -name '*.wav' -print0 | xargs -0 stat -f%z 2>/dev/null | awk '{s+=$1} END {print s+0}')
log "total fixture WAV size: ${total} bytes"
if (( total > MAX_BYTES_TOTAL )); then
  warn "fixtures dir exceeds 3 MB total (${total} bytes)"
fi

log "done."
