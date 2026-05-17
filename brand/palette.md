# Murmur Brand Palette

## Voice & personality

Murmur is local-first voice typing for the Mac. Yours, instantly. The brand
feels like a good fountain pen on warm paper: editorial, writerly, and quiet.
It is the opposite of a generic AI product. There are no exclamation points in
the headings, no purple-blue gradients, no "supercharge." Confidence is shown
by restraint — by knowing the right word, by trusting the reader, by leaving
silence around the work. When Murmur speaks, it murmurs.

## Palette

| Name              | Hex       | Usage                                              | Accessibility & notes |
|-------------------|-----------|----------------------------------------------------|------------------------|
| Off-white (paper) | `#F8F4EE` | Primary app background, marketing canvas           | Warm neutral. Pairs with ink at 14.9:1 — well above WCAG AAA. |
| Warm white (card) | `#FFFBF5` | Card surfaces, icon background, modal sheets       | One step lighter than paper for layering. Avoid stacking three deep — the contrast steps are intentionally narrow. |
| Ink               | `#1A1A1A` | Primary text, wordmark, glyph fills                | Not pure black. On warm-white card it reads 14.9:1 — passes AAA at any size. |
| Mute red          | `#C2362F` | Recording active, accent, the whisper-decay dot    | On warm-white (`#FFFBF5`) it measures **5.20:1** against ink — passes WCAG AA for normal text (14px+) and AA Large at any weight. Do not use mute red as a text color on the off-white background below 16px without bumping to semibold. Do not place mute red text on the ink color (1.4:1 — fails). |
| Success green     | `#3F7A4A` | Successful transcription / inserted confirmation   | On warm-white achieves 4.97:1 — passes AA at 14px+. Reserve for confirmations; never use as a primary accent. |
| Muted gray        | `#7A7670` | Secondary text, metadata, dividers                 | On warm-white achieves 4.51:1 — passes AA Large only. **Do not use below 18px regular / 14px bold.** For body-weight metadata, darken to `#5E5B57` instead. |

### Pairing rules

- Ink on paper, ink on card — always safe.
- Mute red on card or paper — safe for accents, icons, and headings 16px+.
- Mute red on ink — **never** (fails contrast and reads as alarming).
- Success green is a confirmation color only. It must never appear alongside
  mute red in the same moment of UI; the two states are mutually exclusive.

## Typography

Murmur ships zero web fonts. This is a deliberate brand and engineering choice:
it avoids font licensing review, avoids notarization complications around
embedded resources, keeps the app and marketing site instant on first paint,
and lets the macOS system render its native serifs and SF stack — which is
already the most refined typography on the platform.

| Role             | Stack |
|------------------|-------|
| Hero / wordmark  | `ui-serif, "New York", Georgia, "Times New Roman", serif` |
| UI sans          | `-apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", sans-serif` |
| Mono / captions  | `ui-monospace, "SF Mono", Menlo, monospace` |

Display copy and the wordmark use the high-contrast serif. Product UI uses the
system sans. Transcripts, code, and shortcut keys use mono. Italics are
reserved — they belong to the wordmark's two `m` glyphs and to in-flow emphasis;
they are not a decorative texture.

## Voice guide

**Do**
- Be confident, quiet, and specific. "Press Fn. Speak. Release."
- Name the mechanism. "Runs entirely on your Mac." "Whisper, on-device."
- Trust the reader. Short sentences. One idea per line.
- Use the em dash sparingly — like this — and only when a comma can't.

**Don't**
- "World-class." "AI-powered." "Supercharge." "Revolutionary." "Game-changing."
- Exclamation points in headings. Ever.
- Purple-to-blue gradients. Glassmorphism. Neon. Drop shadows on text.
- Promise privacy with the word "secure." Show it. ("No network calls. Verify
  with Little Snitch.")
- Stack more than one adjective in front of a noun.

## Asset inventory

Master files live in `brand/` and are the single source of truth:

```
brand/
  palette.md           ← this file
  icon.svg             ← squircle app icon, italic m + sine + red dot
  wordmark.svg         ← "Murmur" wordmark, ink on light
  wordmark-inverse.svg ← paper on ink, for dark surfaces
```

Consumed by:

- `app/Resources/Assets.xcassets/AppIcon.appiconset/` — icon.svg is exported
  through the icon pipeline to the required `.png` sizes (16, 32, 64, 128,
  256, 512, 1024, plus @2x).
- `website/` — wordmark + inverse for nav, footer, social cards.
- `docs/assets/` — wordmark for documentation headers and README.
- `.github/` — square icon for the social preview image.

When any of these change, update the master in `brand/` first, then propagate.
The master files are checked in; the exports are regenerated.
