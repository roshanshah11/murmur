#!/usr/bin/env bash
set -euo pipefail

# Render AppIcon.iconset from the brand master and compile to .icns.
# Run this whenever brand/icon.svg or website/apple-touch-icon.svg changes.
#
# Master: website/apple-touch-icon.svg
#   The complex brand/icon.svg (italic m + damped sine decay tail + red
#   dot) smears at 16/32px — the three downstrokes and the tail collapse
#   into a blurry mass and the red dot disappears. The simpler letterform
#   in website/apple-touch-icon.svg (clean italic serif m + red period
#   dot, warm cream squircle) reads at every required size. We use the
#   same glyph at every size per Apple HIG so there is no visual jump
#   between dock (128) and Finder list (16/32).
#
# Requires:
#   - rsvg-convert     (brew install librsvg)
#   - iconutil         (built-in to macOS)
#
# Output:
#   app/Resources/AppIcon.iconset/   (10 PNGs)
#   app/Resources/AppIcon.icns       (compiled iconset)

cd "$(dirname "$0")/.."

MASTER_SVG="../website/apple-touch-icon.svg"
ICONSET_DIR="Resources/AppIcon.iconset"
ICNS_OUT="Resources/AppIcon.icns"

if [ ! -f "$MASTER_SVG" ]; then
  echo "Master SVG not found at $MASTER_SVG" >&2
  exit 2
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not found. Install with:" >&2
  echo "  brew install librsvg" >&2
  exit 2
fi

if ! command -v iconutil >/dev/null 2>&1; then
  echo "iconutil not found. This script must run on macOS." >&2
  exit 2
fi

echo "Rendering AppIcon.iconset from $MASTER_SVG ..."
mkdir -p "$ICONSET_DIR"

# Iconset filename -> pixel size, per Apple iconutil spec.
# Format: "<filename>:<size>"
SIZES=(
  "icon_16x16.png:16"
  "icon_16x16@2x.png:32"
  "icon_32x32.png:32"
  "icon_32x32@2x.png:64"
  "icon_128x128.png:128"
  "icon_128x128@2x.png:256"
  "icon_256x256.png:256"
  "icon_256x256@2x.png:512"
  "icon_512x512.png:512"
  "icon_512x512@2x.png:1024"
)

for entry in "${SIZES[@]}"; do
  fname="${entry%%:*}"
  px="${entry##*:}"
  out="${ICONSET_DIR}/${fname}"
  rsvg-convert -w "$px" -h "$px" "$MASTER_SVG" -o "$out"
  printf "  %-26s %4dx%-4d  %s\n" "$fname" "$px" "$px" "$(stat -f '%z' "$out") bytes"
done

echo "Compiling $ICNS_OUT ..."
iconutil --convert icns "$ICONSET_DIR" --output "$ICNS_OUT"

ICNS_SIZE=$(stat -f '%z' "$ICNS_OUT")
echo "Done. $ICNS_OUT ($ICNS_SIZE bytes)"
