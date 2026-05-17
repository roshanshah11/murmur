# `demo.svg` — procedural fallback for the hero demo

`demo.svg` is a pure-SVG, JS-free, 1280×800, ~6-second SMIL animation that
walks through the Murmur dictation flow in four "frames":

1. **00:00–01:5** Cursor blinks in a Notes-style editor card.
2. **01:5–03:0** A black notch pill drops down from the top of the card with a
   "MURMUR" idle label.
3. **03:0–04:5** The pill flips to its active state — pulsing red dot,
   nine-bar spectrum, and a "LISTENING" caption.
4. **04:5–06:0** A green check + "PASTED" appears in the pill, the caret jumps
   across the line, and the dictated sentence — *"Murmur transcribes locally
   on a MacBook with no network."* — fades in at the caret's resting position.

The right-hand column has four typeset captions ("Cursor rests.", "Pill drops.",
"Bars listen.", "Text lands.") and a red highlighter rectangle that travels
between them in sync with the frames. A timecode strip and a red playhead at
the bottom give a "filmstrip" feel.

The italic-`m` brand mark with the red endmark dot sits in the top-right
corner. The whole composition lives on the same paper-cream palette as the
landing page (`#EFE9DD` paper, `#1C1814` ink, `#B23A2A` red).

## Why an SVG, not a video?

- **Zero binary deps.** Renders identically on every browser that ships SMIL
  (Safari, Chrome, Firefox today).
- **Tiny.** ~10 KB on the wire, gzips to <4 KB. Smaller than even a single
  poster frame as `.webp`.
- **Reduced-motion safe.** A `@media (prefers-reduced-motion: reduce)` rule
  hides every `<animate>` / `<animateTransform>` element, so the SVG falls
  back to its initial state (a clean editor with the notch pill hidden).
- **No autoplay policy issues.** Browsers won't block it like they sometimes
  block `<video autoplay muted>` on cellular or low-power.

## When to wire it into `index.html`

Right now (Phase 10) the landing page's `.demo-frame` shows a CSS-drawn
dual-card mockup. That mockup is the most reliable "demo" because it's plain
DOM, picks up the page palette, and never errors.

**Do not** swap `demo.svg` into the hero yet. Treat it as a Phase 13 polish
candidate or as the in-the-middle fallback layer when the real video lands.

When you do wire it in, the recommended markup is:

```html
<figure class="demo-frame">
  <video
    autoplay loop muted playsinline preload="metadata"
    poster="/demo-poster.svg"
    width="1280" height="800"
    aria-label="Murmur dictation demo">
    <source src="/demo.webm" type="video/webm">
    <source src="/demo.mp4"  type="video/mp4">
    <!-- Fallback for browsers that can't decode either codec, or that
         have JS / video disabled. SMIL animates inside. -->
    <img src="/demo.svg" alt="Animated demo of Murmur dictating into an editor"
         width="1280" height="800" loading="lazy" decoding="async">
  </video>
</figure>
```

The `<img>` fallback inside `<video>` is intentional — browsers that can't
play either source will render the SVG (animations and all). The CSS-drawn
dual-card mockup should remain as a sibling node, gated behind a
`<noscript>`-style fallback or removed only once the real `demo.mp4` ships.

## Files

| File              | Purpose                                  | Size  |
|-------------------|------------------------------------------|-------|
| `demo.svg`        | Animated 6-second SMIL loop              | ~10 KB |
| `demo-poster.svg` | Single static frame (frame 3, listening) | ~6 KB  |

Both files are committed to `website/` and served from the site root via
Vercel's static handler.
