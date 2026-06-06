---
title: Models
---

# Models

Murmur supports two transcription engines. Switch between them in **Settings → Models**.

## Transcription engines

### Parakeet (default on Apple Silicon)

NVIDIA `parakeet-tdt-0.6b-v3`, loaded through the [FluidAudio SDK](https://github.com/fluidaudio/fluidaudio) and executed on the **Apple Neural Engine** via Core ML. Requires macOS 14 (Sonoma) or later.

- ~470 MB one-time download from Hugging Face (via FluidAudio), SHA-verified.
- Covers **25 European languages** — including English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Czech, Slovak, Russian, Ukrainian, Bulgarian, Croatian, Serbian, Greek, Finnish, Swedish, Danish, and more.
- Fastest and most accurate for English on Apple Silicon. Chosen automatically when you're on an M-series Mac.

### Whisper.cpp (fallback / default on Intel)

[whisper.cpp](https://github.com/ggerganov/whisper.cpp) with Metal acceleration on Apple Silicon and OpenBLAS on Intel. Covers **99 languages**. The right pick when you need a language Parakeet doesn't support, or when running on an Intel Mac.

The GGML model sizing table below applies to the **Whisper engine**. You pick the Whisper model size in **Settings → Models**; the Parakeet engine has no size variants to choose.

---

Pick the Whisper model that fits your Mac. Download, verify, switch, or delete from **Settings → Models**.

## Sizing table

| Model | Disk | Peak RAM | Apple Silicon (M2) | Intel (i7 2019) | Quality | When to pick it |
|---|---|---|---|---|---|---|
| `tiny.en` | 75 MB | ~390 MB | ~10× realtime | ~3× | Rough | Live captions, single-word commands |
| `tiny` (multi) | 75 MB | ~390 MB | ~10× | ~3× | Rough | Same, but non-English |
| `base.en` | 142 MB | ~500 MB | ~7× | ~2× | Solid (default) | Default for everyday English dictation |
| `base` (multi) | 142 MB | ~500 MB | ~7× | ~2× | Solid | Non-English, light hardware |
| `small.en` | 466 MB | ~1.0 GB | ~4× | ~1× | Better | English with technical jargon |
| `small` (multi) | 466 MB | ~1.0 GB | ~4× | ~1× | Better | Mixed-language or accented English |
| `medium.en` | 1.5 GB | ~2.6 GB | ~2× | ~0.5× | Great | Long dictations, dense vocabulary |
| `medium` (multi) | 1.5 GB | ~2.6 GB | ~2× | ~0.5× | Great | Same, multilingual |
| `large-v3` | 2.9 GB | ~5.0 GB | ~1× | not recommended | Best | Accuracy-first, M-series only |

*Speeds are wall-clock for a 30-second monologue, rounded. Your mileage varies with thermal state, model warm-up, and audio quality.*

## `.en` vs multilingual

- **`.en` variants** are trained only on English. They're a hair more accurate on English and a hair faster, at the same parameter count.
- **No-suffix variants** handle 99 languages. Pick these if you ever switch language mid-dictation, or if your native language is not English.

You can have both installed; Murmur only loads the active one into RAM.

## Download

1. Open **Settings → Models**.
2. Click **Download** next to the model you want.
3. Wait. Murmur shows progress and verifies SHA-256 against the bundled manifest. A mismatch aborts the download and deletes the partial file.

Murmur fetches from the official whisper.cpp Hugging Face mirror:

```
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-<model>.bin
```

These are the only network calls the Whisper engine makes besides the Sparkle update check. The Parakeet engine similarly downloads its model once from Hugging Face (via FluidAudio); see [Privacy](privacy.md) for the full network surface.

## Where they live

```
~/Library/Application Support/Murmur/Models/
├── ggml-base.en.bin
├── ggml-base.en.bin.sha256
├── ggml-small.en.bin
└── ggml-small.en.bin.sha256
```

The `.sha256` sidecar is re-verified at app launch. A mismatch quarantines the model and prompts a re-download.

## Switch the active model

**Settings → Models → Set active** on the row you want. The switch is instant; the next dictation uses the new model.

## Delete a model

**Settings → Models → ⋯ → Delete**. Deleting the active model prompts you to pick a replacement first.

You can also delete by hand:

```bash
rm "$HOME/Library/Application Support/Murmur/Models/ggml-medium.en.bin"
rm "$HOME/Library/Application Support/Murmur/Models/ggml-medium.en.bin.sha256"
```

## Recommended starting picks

| Machine | Pick |
|---|---|
| M1 / M2 / M3 / M4 Air, base RAM | `base.en` |
| M-series Pro / Max | `small.en` or `medium.en` |
| M-series Ultra / 64 GB+ | `large-v3` |
| Intel quad-core, 16 GB | `base.en` |
| Intel dual-core, 8 GB | `tiny.en` |

## Next

- [Vocabulary](vocabulary.md) — even a tiny model gets your acronyms right with a small word list.
- [Troubleshooting](troubleshooting.md#model-download-stuck) for a stalled download.
