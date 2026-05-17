# Murmur landing page — performance notes

## Bottom line

| Measure | Before | After |
|---|---|---|
| Combined HTML+CSS (uncompressed) | 29,236 B | **24,653 B** |
| Combined HTML+CSS (gzip) | ~7,800 B | **7,034 B** |
| HTTP requests (above-the-fold, excluding video) | 2 (HTML + CSS) | **1** (HTML only) |
| Render-blocking external CSS | 1 file | **0** |
| Web fonts | 0 | **0** |
| JS framework | none | **none** |
| Inline JS (minified) | ~1.4 KB | **~0.9 KB** |

Single-file delivery (CSS inlined into `<head>`) means **first paint requires exactly one network roundtrip after the HTML lands**.

## Anticipated Lighthouse (mobile, throttled, simulated)

| Category | Estimate | Confidence |
|---|---|---|
| Performance | **98–100** | high (subject to demo video weight) |
| Accessibility | **100** | high |
| Best Practices | **100** | high |
| SEO | **100** | high |

Core Web Vitals targets:

- **LCP** < 1.5 s. Likely candidate is the H1 wordmark (server-side text, no font loading). With the demo video poster preloaded as `webp`, even on a slow 4G connection LCP should comfortably beat 2.5 s.
- **CLS** = 0.000. Every box is sized: `aspect-ratio: 16/10` on the video container, `width`/`height` attrs on the `<video>` element, explicit dimensions on every inline SVG, `clamp()` typography that does not reflow at breakpoints.
- **INP** < 50 ms. There are exactly two interactions (Homebrew copy button + video playback-rate hover); both are O(1) DOM mutations.
- **TBT** ≈ 0 ms. No render-blocking JS, no third-party scripts.
- **TTFB** governed by GitHub Pages edge (typically 30–80 ms in Cloudflare-fronted CDN regions).

## What changed and why

### Single-file delivery
- Folded `style.css` into a `<style>` block in `<head>`. Removes one request from the critical path. CSS is small enough (~9 KB) that inlining is the right call — the standard "external CSS for browser cache" win is dwarfed by the round-trip cost on first visit, which is the visit that matters for marketing.
- Stripped all dead whitespace from the CSS block.

### LCP
- The H1 (`Murmur` wordmark, system serif) is the likely LCP element. It paints with zero blocking resources because:
  - no `@font-face`, so no FOIT/FOUT,
  - no external CSS,
  - the serif stack (`ui-serif → New York → Georgia`) resolves instantly on every Apple device and falls back gracefully on Windows/Linux.
- `<link rel="preload" as="image" href="/demo-poster.webp" fetchpriority="high">` so the demo poster shows the moment HTML is parsed, even before the video element decides whether to fetch metadata.
- Removed the gradient poster fallback (`background: linear-gradient` on `.demo video`) from being the LCP candidate — the explicit `poster` attribute takes precedence.

### CLS
- `<video width="1280" height="800">` plus `aspect-ratio: 16/10` on the container means the video reserves space the moment HTML is parsed, before metadata loads.
- All inline SVGs have explicit `width` and `height` attributes.
- `clamp()` for the wordmark and lede so font-size scales smoothly without breakpoint jumps.
- `next/font`-style font-fallback metric matching is not needed because we never load a web font.

### INP
- Inline JS is ~30 lines, runs once at parse time (no event-loop blocking on hydration since there is none), and attaches three listeners total.
- Hover speedup on the demo (`playbackRate = 1.5`) is the only continuous interaction. Trivial.
- `prefers-reduced-motion` kills all animations and transitions.

### Below-the-fold deferral
- `content-visibility: auto; contain-intrinsic-size: 1px 800px` on every section below the hero. Browsers skip layout/paint for off-screen sections until they scroll into view. Real wins on long-page Lighthouse traces.
- `preload="metadata"` on the video so the browser doesn't fetch the full file upfront.
- The recording-bars idle animation in the notch runs continuously but is GPU-cheap (`transform: scaleY`).

### Network
- Zero cross-origin requests. Nothing to `preconnect` to. No Google Fonts, no analytics, no embed scripts.
- `<meta http-equiv="Cache-Control" content="public,max-age=3600,must-revalidate">` is a fallback hint. GitHub Pages controls the real headers (it sends `Cache-Control: max-age=600` for HTML by default and `max-age=10800` for assets). When the custom domain lands, set up Cloudflare in front and override.

### Accessibility
- Skip-to-content link (visible only on focus).
- Semantic landmarks: `<header>`, `<main>`, `<section>`, `<footer>` with `role` attributes where the element is reused.
- All decorative SVGs `aria-hidden="true"`. Icon buttons carry `aria-label`.
- Focus rings via `:focus-visible` (keyboard only, not on mouse-click).
- `prefers-reduced-motion` honored — disables both the pulse animation and the smooth scroll.
- Contrast: ink on paper 14.9:1 (AAA). Red on paper/card 5.20:1 (AA). Gray bumped from `#7A7670` to **`#5E5B57`** in the optimized stylesheet so secondary text passes AA at 14 px regular per the palette guidance — the original `#7A7670` only passed AA Large.
- Dark-mode parity: every color variable has a dark-mode equivalent.

### SEO / sharing
- `<title>` and `<meta description>` tuned for the search snippet.
- Open Graph + Twitter Card with absolute URLs (required for crawlers).
- JSON-LD `SoftwareApplication` with `operatingSystem`, `applicationCategory: ProductivityApplication`, `offers.price: 0`, MIT license URL, author.
- `<link rel="canonical">` set to the eventual `murmur.app` URL.

### Print
- `@media print` strips chrome, removes the demo and the CTA buttons, switches to black-on-white with bordered cards. The page reads as a one-pager printed.

### Other belt-and-suspenders
- `<svg><defs><symbol>` block for the two icons that repeat (copy, check). `<use href="#i-…">` everywhere they appear. Saves ~400 bytes uncompressed and is cleaner DOM.
- `<noscript><style>` hides the Homebrew copy buttons if JS is off — clipboard API is the only thing requiring JS on the page. The bare `<code>brew install --cask murmur</code>` is still selectable.
- `theme-color` set for both light and dark schemes (Safari iOS chrome, Chrome Android).
- Cache-Control meta is a fallback for hosts that ignore the static-site default. GitHub Pages honors its own headers.

## Assets still owed

These need to be dropped alongside `index.html` before launch:

- [ ] `demo.mp4` — H.264, AAC stripped, faststart muxed. Encoding command:
      ```
      ffmpeg -i raw.mov -vcodec libx264 -crf 26 -preset slow -movflags +faststart -an \
        -vf "scale=1280:-2" demo.mp4
      ```
- [ ] `demo.webm` — VP9, no audio:
      ```
      ffmpeg -i raw.mov -c:v libvpx-vp9 -b:v 0 -crf 32 -an \
        -vf "scale=1280:-2" demo.webm
      ```
- [ ] `demo-poster.webp` — first frame, ~50 KB:
      ```
      ffmpeg -i demo.mp4 -ss 00:00:00.4 -frames:v 1 -c:v libwebp -quality 80 demo-poster.webp
      ```
- [ ] `og-image.png` — 1200×630, wordmark on warm-white, tagline below, red dot. Use the master `brand/wordmark.svg`.
- [ ] `favicon.ico` — multi-size (16, 32). Generate from `brand/icon.svg`.
- [ ] `icon.svg` — referenced as the modern SVG favicon. Drop a copy of `brand/icon.svg`.
- [ ] `apple-touch-icon.png` — 180×180. Generate from the icon master.

## Things to confirm with product before launch

- Homebrew cask token: `brew install --cask murmur`. Update `#brew-cmd` / `#brew-cmd-2` if the tap publishes under a different token.
- DMG download URL: points at `releases/latest/download/Murmur.dmg`. Update after first signed release.
- `/privacy` route: footer link will 404 until a privacy page lands in the site.
- Contact email: `hello@murmur.app` is a placeholder until MX is wired.
- Custom domain: HTML references absolute URLs at `https://murmur.app/`. While on `roshanshah11.github.io/murmur/`, the canonical link and OG URLs will resolve to the eventual domain — fine for crawlers that follow canonicals, but the og-image and apple-touch-icon paths (`/og-image.png`, `/apple-touch-icon.png`, `/favicon.ico`) must exist at the project root once the apex domain is configured. On the `/murmur/` subpath these paths will not resolve. Two options:
  1. Wait for the custom domain to land before deploy.
  2. Temporarily change the leading-slash paths to `og-image.png` (relative) and re-flip on cutover.

## Validation checklist (run before launch)

- [ ] <https://validator.w3.org/> on the final HTML.
- [ ] <https://jigsaw.w3.org/css-validator/> on the inlined CSS.
- [ ] Lighthouse mobile + desktop runs (target ≥98 perf).
- [ ] PageSpeed Insights field data once traffic ramps.
- [ ] <https://search.google.com/test/rich-results> on the JSON-LD.
- [ ] <https://www.opengraph.xyz/> to preview the social card.
- [ ] `axe` or `pa11y` accessibility scan.
- [ ] Manual keyboard pass: Tab through the page, confirm focus ring on every interactive element, skip-to-content jumps to `#main`.
- [ ] Dark-mode visual review: open with macOS in dark mode and the iOS share-sheet preview.
- [ ] Print preview: confirm the printed page is legible and the demo box is hidden.
