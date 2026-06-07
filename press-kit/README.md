# Murmur — Press Kit

Local-first dictation for the Mac. Hold `fn`, speak, paste. Nothing leaves the machine.

---

## About Murmur

Murmur is a small, opinionated dictation utility for macOS. You hold the `fn` key, speak, release, and a transcript lands at the cursor — in whatever app already had focus. The entire pipeline runs on the Mac. Whisper, on-device. No account, no cloud, no telemetry, no socket opened during a session. The audio file lives for a few seconds in a cache directory and is removed the moment its transcript reaches the clipboard.

Murmur is MIT-licensed and free, forever. It ships zero web fonts, zero analytics, zero "AI" branding. The only way to verify the privacy claims is the only way that ever really matters: read the source.

---

## The pitch, in three lengths

### Thirty words

Murmur is local-first voice typing for the Mac. Hold `fn`, speak, release, paste. Whisper runs on your machine. No cloud, no account, no telemetry. MIT-licensed and free.

### One hundred words

Murmur is a quiet macOS dictation app. Hold `fn`, speak, release — a transcript lands at the cursor in whichever app held focus. The entire pipeline runs locally on Apple Silicon or Intel using whisper.cpp. No network call is made during a dictation. No analytics, no crash reports, no account. Audio is cached for seconds, then deleted; the transcript is never written to any log unless you opt into History. Four cleanup profiles (Raw, Casual, Formal, Code) apply deterministic rules — no LLM rewrite of what you said. MIT-licensed. Free, forever.

### Two hundred fifty words

Murmur is a local-first dictation utility for macOS. It does one thing: you hold the `fn` key, speak, release, and cleaned text drops into whichever app held the cursor. A small pill slides down from the notch while you talk and disappears the moment you stop.

The transcription runs entirely on your Mac. Murmur ships whisper.cpp, accelerated on the Apple GPU, and picks a model that fits your hardware. No socket opens during a dictation. No account is required to install. The cached audio file is removed the moment its transcript reaches the clipboard, and the transcript itself is never written to disk unless you opt into the History window.

Cleanup is deterministic. Murmur offers four profiles — Raw, Casual, Formal, Code — that apply explicit rules to spoken text. There is no second model rewriting what you said. A vocabulary editor lets you teach Murmur the proper names and acronyms it keeps mishearing.

Updates ship via Sparkle from a public appcast; the binary is signed and notarized. The app is MIT-licensed, so the privacy claims are auditable by the only mechanism that ever really matters — reading the source.

Murmur runs on macOS 13 and later, on both Apple Silicon and Intel. It is free, forever. Install it with `brew install --cask roshanshah11/murmur/murmur` or grab the DMG from the GitHub releases page.

---

## Key facts

| | |
|---|---|
| Platforms | macOS 13 Ventura and later |
| Architectures | Apple Silicon and Intel |
| License | MIT |
| Price | Free, forever |
| Network | None during a dictation. Sparkle checks an appcast for updates. |
| Account | Not required. There is no account. |
| Telemetry | None. No analytics, no crash reports, no anonymous pings. |
| Engine | whisper.cpp, GPU-accelerated on Apple Silicon |
| Cleanup | Four deterministic profiles: Raw, Casual, Formal, Code |
| Updates | Sparkle, from a public appcast — signed and notarized |

---

## Maintainer

Roshan Shah — [ashah@alixpartners.com](mailto:ashah@alixpartners.com)

For press, podcast, or review enquiries, email is the fastest route. Please include your outlet and an embargo date if relevant.

---

## Links

- Landing page: <https://murmur-landing-phi.vercel.app/>
- Source: <https://github.com/roshanshah11/murmur>
- Releases: <https://github.com/roshanshah11/murmur/releases>
- Documentation: <https://github.com/roshanshah11/murmur/tree/main/docs>
- Sponsor: <https://github.com/sponsors/roshanshah11>

---

## What's in this kit

```
press-kit/
  README.md            ← this file
  colors.md            ← brand palette, hex codes, named uses
  copy-snippets.md     ← taglines, tweets, paragraphs at fixed lengths
  logos/
    icon.svg           ← master app icon (italic m + decay dot)
    icon-1024.png      ← 1024 × 1024 raster
    wordmark-light.svg ← wordmark for light backgrounds
    wordmark-light-1600.png  ← 1600 × 400 raster
    wordmark-dark.svg  ← wordmark for dark backgrounds
    wordmark-dark-1600.png   ← 1600 × 400 raster
  screenshots/
    README.md          ← inventory of the six canonical shots
```

The PNGs are the right size for blog hero images and social cards. The SVGs are master files — scale them freely and they will stay sharp.

---

## What not to do with these assets

Please do not:

- Recolor the wordmark outside the palette in `colors.md`. The italic `m` is the wordmark; do not redraw it.
- Place the wordmark over photography or a busy background without an off-white or ink plate behind it.
- Add a drop shadow, gradient, or outer glow to the icon or wordmark.
- Imply that Murmur transcribes in the cloud, uses a third-party API, or trains a model on your voice. None of those things are true.
- Describe Murmur as "AI-powered" or "powered by GPT." Murmur runs Whisper locally and is opinionated about that distinction.
- Use the assets to promote a derivative product without making clear that it is a fork.

The MIT license governs the code, not the brand. Reach out if you are unsure.
