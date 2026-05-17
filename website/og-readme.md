# Murmur — Open Graph image

Card shown by Slack, iMessage, Twitter/X, LinkedIn, Discord, Notion, etc. when
someone shares `https://murmur-landing-phi.vercel.app/`.

## Files

| File | Role |
| --- | --- |
| `og-image.svg` | Master, hand-tuned, vector. Open in a browser to preview. |
| `og-image.html` | Pixel-faithful HTML fallback. Use when `rsvg-convert` is unavailable. |
| `og-image.png` | The published raster the social crawlers actually fetch. **Required.** |

The HTML in `index.html` references `/og-image.png` — that file MUST exist on
the deployed site or you'll see a broken preview.

## Dimensions

- Canvas: **1200 × 630** (the universal `summary_large_image` size).
- File-size target: keep `og-image.png` under **800 KB** (Twitter caps fetch
  at 5 MB but slow CDNs choke earlier; LinkedIn quietly drops anything > 5 MB).
- The SVG master should stay **≤ 8 KB** (currently ~6 KB).

## Conversion (preferred — rsvg-convert)

```bash
# one-time install
brew install librsvg

# render
rsvg-convert -w 1200 -h 630 -f png \
  -o website/og-image.png website/og-image.svg

# optional: pngquant the result to ~150 KB
brew install pngquant
pngquant --quality=80-92 --force --output website/og-image.png website/og-image.png
```

## Conversion (fallback — Chrome headless on the HTML file)

If `rsvg-convert` isn't installed but you have Chrome / Brave / Edge:

```bash
# adjust the binary name for your install
chrome \
  --headless --disable-gpu \
  --hide-scrollbars \
  --window-size=1200,630 \
  --screenshot=website/og-image.png \
  "file://$(pwd)/website/og-image.html"
```

## Conversion (fallback — Playwright)

If you've already got Playwright in another project, run from there:

```js
// node screenshot-og.js
import { chromium } from 'playwright';
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.goto('file:///absolute/path/to/website/og-image.html');
await page.screenshot({ path: 'website/og-image.png', clip: { x: 0, y: 0, width: 1200, height: 630 } });
await browser.close();
```

## Dimensions check

After rendering, verify with `sips` (built-in on macOS):

```bash
sips -g pixelWidth -g pixelHeight website/og-image.png
# pixelWidth: 1200
# pixelHeight: 630
```

## Verifying social previews

```bash
# Twitter/X
open "https://cards-dev.twitter.com/validator?url=https://murmur-landing-phi.vercel.app/"

# Facebook / Meta debugger (also covers Instagram, WhatsApp, Threads)
open "https://developers.facebook.com/tools/debug/?q=https://murmur-landing-phi.vercel.app/"

# LinkedIn Post Inspector
open "https://www.linkedin.com/post-inspector/inspect/https://murmur-landing-phi.vercel.app/"

# iMessage / Slack / Discord — paste the URL into a draft message.
```

Caches are aggressive. After a redeploy, hit the Facebook debugger's
**Scrape Again** and Twitter's validator once to bust each platform's cache.

## When to regenerate

Re-export the PNG (and re-deploy) whenever any of these change:

- The brand palette in `/brand/palette.md`.
- The wordmark or icon SVGs in `/brand/`.
- The product tagline (`Local-first dictation for macOS. Double-tap fn, speak, paste.`).
- The release marker on the issue line (`VOL. 1 · NO. 1 · MAY 2026`) — bump on major releases.
- The published URL (currently `murmur-landing-phi.vercel.app` → swap for the
  bare-domain when DNS lands).

## Design notes

Locked palette (hex, not vars — renderers don't evaluate CSS custom properties
inside SVG):

| Token | Hex | Use |
| --- | --- | --- |
| `--paper` | `#EFE9DD` | Canvas |
| `--ink` | `#1C1814` | Wordmark, headline |
| `--ink-soft` | `#46403A` | Standfirst, meta |
| `--ink-fade` | `#7D766B` | Issue line, ornaments |
| `--red` | `#B23A2A` | Endmark dot, sine fragment, pip |
| `--gold` | `#94774A` | Three rules on the right |

Typography is system-only: `ui-serif, New York, Georgia, serif` and
`ui-sans-serif, -apple-system, sans-serif`. The browser/macOS substitutes the
real face at raster time; that's why we render to PNG before publishing.
