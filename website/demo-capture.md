# Capturing the real Murmur demo video

The landing page hero references `demo.mp4`, `demo.webm`, and
`demo-poster.webp`. This document is the exact recipe for producing those
three binaries from a single screen recording.

You need: a Mac that has Murmur installed (`/Applications/Murmur.app`),
a working microphone, accessibility + microphone permissions granted to
Murmur, and `ffmpeg` (`brew install ffmpeg`).

## 0. Pre-flight

- Quit Slack, Teams, anything that might steal focus or pop a notification.
- Put your Mac in Do Not Disturb (`⌃⌥⇧D` in macOS 13+).
- Set the display to 1280×800 logical resolution if you can (or to whatever
  pixel-density gives you a clean retina capture; we'll downscale anyway).
- Hide the desktop icons: `defaults write com.apple.finder CreateDesktop false; killall Finder`. Restore with `true`.
- Verify Murmur is launched and the menubar item is present.
- Open **Notes.app** with a single blank note. Set the font to "Note" style
  so the cursor is large and high-contrast.

## 1. Scene direction (target ≈ 6 seconds)

| t        | action                                                     |
|----------|------------------------------------------------------------|
| 0.0–1.0s | Empty Notes window, cursor blinking. Hold still.            |
| 1.0s     | Double-tap `fn`. Notch pill drops in with the idle label.   |
| 1.4–4.0s | Say, clearly: *"Murmur transcribes locally on a MacBook with no network."* |
| 4.0s     | Stop speaking. Pill shows the "PASTED" check briefly.       |
| 4.0–6.0s | The transcribed sentence is now in Notes at the caret.      |

Practice it twice before recording. A clean take beats post-production.

## 2. Raw capture

Use macOS's built-in screen recorder (⌘⇧5) so you get the cleanest possible
H.264 source, OR drive it from `ffmpeg`:

```bash
# List avfoundation devices first so you know the screen index
ffmpeg -f avfoundation -list_devices true -i ""

# Record the main display (index typically 1 on retina Macs) at 30 fps,
# 1280×800 logical -> 2560×1600 physical -> we capture native + downscale.
# -t 7 gives a 7-second buffer so you can trim the head/tail cleanly.
ffmpeg -y \
  -f avfoundation \
  -capture_cursor 1 \
  -framerate 30 \
  -i "1" \
  -t 7 \
  -vf "crop=2560:1600:0:0,scale=1280:800:flags=lanczos" \
  -c:v libx264 -preset ultrafast -crf 18 -an \
  raw.mov
```

You can also screen-record at default fps with ⌘⇧5 → Record Selected
Portion → 1280×800 region → save to `raw.mov`. Either way, the rest of the
pipeline assumes `raw.mov` is a ~6–7s 1280×800 H.264.

## 3. Trim to exactly 6 seconds

```bash
# Adjust -ss (start) to skip the "click record" frames; -t 6 caps the length.
ffmpeg -y -i raw.mov -ss 0.4 -t 6 -c copy raw-trimmed.mov
```

## 4. Encode `demo.mp4` (H.264, ≤ 1.5 MB)

```bash
ffmpeg -y -i raw-trimmed.mov \
  -c:v libx264 -profile:v high -level 4.0 \
  -crf 28 -preset slow -pix_fmt yuv420p \
  -an \
  -movflags +faststart \
  demo.mp4
```

If the result is over 1.5 MB, bump `-crf` to 30 or 32. For a 6-second 1280×800
mostly-static scene you should land at ~600 KB to 1.2 MB.

## 5. Encode `demo.webm` (VP9, ≤ 1.0 MB)

```bash
# Two-pass for better quality at the same bitrate.
ffmpeg -y -i raw-trimmed.mov \
  -c:v libvpx-vp9 -b:v 0 -crf 33 \
  -row-mt 1 -threads 4 \
  -an \
  -pass 1 -f null /dev/null

ffmpeg -y -i raw-trimmed.mov \
  -c:v libvpx-vp9 -b:v 0 -crf 33 \
  -row-mt 1 -threads 4 \
  -an \
  -pass 2 \
  demo.webm
```

VP9 typically beats H.264 by ~25% at the same perceptual quality. Expect
~400–800 KB.

## 6. Poster frame `demo-poster.webp` (≤ 80 KB)

Pick the moment the pill is fully active and the bars are mid-bounce — around
t=2.5s in our scene.

```bash
ffmpeg -y -i demo.mp4 -ss 2.5 -frames:v 1 -q:v 75 demo-poster.webp
```

Confirm size: `ls -lh demo-poster.webp` should report < 80 KB. If larger,
re-encode with `-q:v 60`.

## 7. Verify sizes & drop into `website/`

```bash
ls -lh demo.mp4 demo.webm demo-poster.webp
# Target:
#   demo.mp4        ≤ 1.5M
#   demo.webm       ≤ 1.0M
#   demo-poster.webp ≤ 80K

mv demo.mp4 demo.webm demo-poster.webp /path/to/flow_local_mac_prd/website/
```

## 8. Wire-in (after capture lands)

Replace the `<img src="/demo.svg">` fallback inside `.demo-frame` with the
full `<video>` block documented in `demo-readme.md`. Keep the SVG as the
in-`<video>` fallback for browsers without VP9/H.264 (none in practice,
but the cost is zero).

## 9. Cross off `ASSETS-OWED.md`

Once `demo.mp4`, `demo.webm`, and `demo-poster.webp` are committed, remove
their three lines from `website/ASSETS-OWED.md`.

---

**Why these settings?**

- `-crf 28 / 33`: Tested to keep mostly-static screen recordings clean
  while staying under the file-size budget. Hero videos that autoplay must
  be small or the LCP penalty wipes out the visual gain.
- `-an`: No audio track. The hero video plays muted regardless, and a
  silent track still costs ~5 KB.
- `+faststart`: Moves the moov atom to the front of the MP4 so the browser
  can start decoding before the file is fully downloaded.
- WebP poster instead of JPEG: ~30% smaller at equivalent quality, supported
  in every browser that ships in the last 4 years.
