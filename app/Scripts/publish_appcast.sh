#!/usr/bin/env bash
# publish_appcast.sh — Generate and EdDSA-sign a Sparkle appcast for a DMG.
#
# Usage:
#   publish_appcast.sh path/to/Murmur-<version>.dmg path/to/output-dir
#
# Required env:
#   SPARKLE_ED_PRIVATE_KEY — base64-encoded EdDSA private key (the raw key the
#                            Sparkle `sign_update` tool emits to stdin via env).
#
# Optional env:
#   SPARKLE_VERSION        — Sparkle release tag (default: 2.6.3)
#   SPARKLE_DOWNLOAD_BASE  — Base URL where Murmur DMGs are hosted. Used by
#                            generate_appcast for the <enclosure url=...>.
#                            Default: https://github.com/roshanshah11/murmur/releases/download
#
# Sparkle tools are fetched from
#   https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz
# and cached at ./Sparkle/ so re-runs reuse them.

set -euo pipefail

if [ "${#}" -lt 2 ]; then
  echo "usage: $0 path/to/Murmur-<version>.dmg path/to/output-dir" >&2
  exit 64
fi

DMG="$1"
OUT_DIR="$2"

if [ ! -f "$DMG" ]; then
  echo "error: DMG not found: $DMG" >&2
  exit 66
fi
mkdir -p "$OUT_DIR"

: "${SPARKLE_ED_PRIVATE_KEY:?SPARKLE_ED_PRIVATE_KEY is required}"

SPARKLE_VERSION="${SPARKLE_VERSION:-2.6.3}"
SPARKLE_DOWNLOAD_BASE="${SPARKLE_DOWNLOAD_BASE:-https://github.com/roshanshah11/murmur/releases/download}"

SPARKLE_DIR="${SPARKLE_DIR:-$(pwd)/Sparkle}"
SPARKLE_BIN="$SPARKLE_DIR/bin"

if [ ! -x "$SPARKLE_BIN/sign_update" ] || [ ! -x "$SPARKLE_BIN/generate_appcast" ]; then
  echo "==> Downloading Sparkle ${SPARKLE_VERSION}"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
  curl -fsSL "$URL" -o "$TMP/sparkle.tar.xz"
  mkdir -p "$SPARKLE_DIR"
  tar -xJf "$TMP/sparkle.tar.xz" -C "$SPARKLE_DIR" --strip-components=0
fi

if [ ! -x "$SPARKLE_BIN/sign_update" ] || [ ! -x "$SPARKLE_BIN/generate_appcast" ]; then
  echo "error: Sparkle tools not found under $SPARKLE_BIN after extraction" >&2
  exit 70
fi

# Decode the EdDSA private key to a temp file the Sparkle tool can read.
KEYFILE="$(mktemp)"
chmod 600 "$KEYFILE"
trap '__rc=$?; rm -f "$KEYFILE"; exit $__rc' EXIT INT TERM
# Accept either `base64 -D` (macOS) or `base64 -d` (GNU).
if base64 -D </dev/null >/dev/null 2>&1; then
  printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | base64 -D > "$KEYFILE"
else
  printf '%s' "$SPARKLE_ED_PRIVATE_KEY" | base64 -d > "$KEYFILE"
fi

# Stage DMGs into a single directory so generate_appcast can enumerate them.
STAGE="$(mktemp -d)"
trap '__rc=$?; rm -f "$KEYFILE"; rm -rf "$STAGE"; exit $__rc' EXIT INT TERM
cp "$DMG" "$STAGE/"

echo "==> Generating appcast"
# generate_appcast accepts the EdDSA private key file via --ed-key-file.
"$SPARKLE_BIN/generate_appcast" \
  --ed-key-file "$KEYFILE" \
  --download-url-prefix "$SPARKLE_DOWNLOAD_BASE/" \
  -o "$OUT_DIR/appcast.xml" \
  "$STAGE"

if [ ! -f "$OUT_DIR/appcast.xml" ]; then
  echo "error: generate_appcast did not produce appcast.xml" >&2
  exit 70
fi

# Safety gate: refuse to publish a feed that lacks a minimum-OS floor. Sparkle's
# generate_appcast derives <sparkle:minimumSystemVersion> from the app bundle's
# LSMinimumSystemVersion; if it were absent the feed would offer this build to
# older macOS versions it can't run on (FluidAudio needs macOS 14 → crash on
# launch). Fail loudly rather than ship a feed that crashes older clients.
MIN_OS="$(grep -o '<sparkle:minimumSystemVersion>[^<]*</sparkle:minimumSystemVersion>' "$OUT_DIR/appcast.xml" | head -1 | sed -E 's/<[^>]+>//g')"
if [ -z "$MIN_OS" ]; then
  echo "error: generated appcast has no <sparkle:minimumSystemVersion> — refusing to publish." >&2
  echo "       Ensure the .app bundle's LSMinimumSystemVersion is set (see build_app.sh)." >&2
  exit 70
fi

echo "==> Wrote $OUT_DIR/appcast.xml"
echo "    (signed entries for $(basename "$DMG"); minimumSystemVersion=${MIN_OS})"
