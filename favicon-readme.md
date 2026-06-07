# Favicon PNG / ICO fallbacks

Modern browsers consume `favicon.svg` directly. For legacy browsers (Safari < 13,
older Edge, IE) and sharing surfaces (Slack unfurls, Twitter previews) that
prefer raster, generate PNG / ICO fallbacks from the SVG sources.

## Prerequisites

```bash
brew install librsvg imagemagick
```

`rsvg-convert` ships with `librsvg`. `magick` (ImageMagick 7) is used only to
bundle multi-resolution `.ico`.

## PNG fallbacks

```bash
cd website

# Standard favicon PNGs (raster fallback alongside favicon.svg)
rsvg-convert -w 16  -h 16  favicon-source-16.svg -o favicon-16.png
rsvg-convert -w 32  -h 32  favicon-source-32.svg -o favicon-32.png
rsvg-convert -w 48  -h 48  favicon.svg            -o favicon-48.png
rsvg-convert -w 64  -h 64  favicon.svg            -o favicon-64.png

# Apple touch icon (iOS adds the rounded mask itself; deliver a square PNG)
rsvg-convert -w 180 -h 180 apple-touch-icon.svg -o apple-touch-icon.png

# Android / PWA maskable
rsvg-convert -w 192 -h 192 apple-touch-icon.svg -o icon-192.png
rsvg-convert -w 512 -h 512 apple-touch-icon.svg -o icon-512.png

# Open Graph thumbnail (if needed in addition to og-image.png)
rsvg-convert -w 1024 -h 1024 apple-touch-icon.svg -o icon-1024.png
```

## Multi-resolution favicon.ico

```bash
magick favicon-16.png favicon-32.png favicon-48.png favicon.ico
```

Then add to `<head>`:

```html
<link rel="icon" type="image/x-icon" href="/favicon.ico">
```

Place it BEFORE the SVG `<link>` so modern browsers still prefer the SVG.

## Verification

```bash
# Confirm every SVG validates as standalone XML
for f in favicon.svg favicon-source-16.svg favicon-source-32.svg apple-touch-icon.svg; do
  xmllint --noout "$f" && echo "ok: $f"
done

# Confirm each SVG is under 2KB
wc -c favicon.svg favicon-source-16.svg favicon-source-32.svg apple-touch-icon.svg
```
