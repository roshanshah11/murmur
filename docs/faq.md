---
title: FAQ
---

# FAQ

Twenty questions, answered straight. If yours isn't here, try [Troubleshooting](troubleshooting.md) or open an issue on [GitHub](https://github.com/roshanshah11/murmur/issues).

## Does Murmur send my audio to the cloud?

No. Whisper runs on your Mac via [whisper.cpp](https://github.com/ggerganov/whisper.cpp). Audio is captured, transcribed, and deleted locally. The only outbound HTTPS calls Murmur makes are to download a Whisper model the first time and to check for app updates via Sparkle. Neither call carries your transcript or your audio. See [Privacy](privacy.md).

## Will it work on a plane (offline)?

Yes, once you've downloaded a model. Offline is the normal mode. The update check is the only thing that wants the internet, and it fails silently.

## Does it support non-English?

Yes — pick a multilingual model on the [Models](models.md) page (`tiny`, `base`, `small`, `medium`, or `large-v3`). The `.en` variants are English-only.

## Does it handle code dictation?

It handles *talking about code*. The [Code prompt profile](prompts.md#code) maps common spoken punctuation to symbols (`open paren` → `(`) and preserves backtick-wrapped tokens. It is not a programming-language-aware transpiler. Pair it with [Vocabulary](vocabulary.md) for library names.

## Can I bind it to a different key? { #different-key }

Yes. **Settings → Recording → Hotkey** accepts any modifier combo (e.g. `⌘⌥D`, `right ⌘ ×2`, F19). Avoid keys claimed by macOS (`⌘Space`, `⌘Tab`).

## Does it support hold-to-talk?

Yes. **Settings → Recording → Hold-to-talk** flips the default tap-tap-to-toggle behavior into press-and-hold.

## Will it understand my accent?

Whisper is trained on 680k hours of multilingual web audio and handles most accents well at `small` or larger. If you're seeing systematic misses on specific words, encode them in [Vocabulary](vocabulary.md) rather than fighting the model.

## Does it record continuously / spy on me?

No. The mic is opened only between the start and stop events of a recording. Murmur does not maintain a hot mic, does not stream audio in the background, and does not run any wake-word detection. macOS's orange mic indicator is your ground truth.

## Does it learn my voice over time?

No. Whisper is a static model. Murmur does not fine-tune or store voice prints. Personalization happens through your [Vocabulary](vocabulary.md) and [Prompts](prompts.md) — both plain text, both editable.

## Why isn't it in the App Store?

Two reasons:

1. App Store sandboxing forbids the global key monitor that catches `fn`+`fn` from any app.
2. Distributing Whisper models from inside the sandbox would either bloat the bundle or require a server hop we don't want.

The Developer ID + notarization route gets you the same Gatekeeper protection without the sandbox tradeoffs.

## Does Murmur touch the clipboard?

Yes — the paste path uses the clipboard. Murmur saves your previous clipboard contents, swaps in the transcript, simulates `⌘V`, then restores the original clipboard ~150 ms later. If something else races for the clipboard in that window, you may notice. We're tracking a clipboard-free paste path; see [Architecture](architecture.md).

## Does it interfere with Siri Dictation?

Yes if you leave Apple Dictation on — both watch for `fn`+`fn`. Disable Apple Dictation (see [First run](first-run.md#1-disable-apple-dictation)) or rebind Murmur's chord.

## Can I run it on macOS 12 or 13?

No. The minimum is macOS 14 (Sonoma). The default transcription engine — NVIDIA Parakeet via the FluidAudio SDK — uses Core ML features that require macOS 14. Murmur also relies on `SMAppService`, the modern AVAudio session model, and the notch overlay logic that shipped in 13, but Parakeet is now the binding constraint. We don't backport.

## How big is the model?

From 75 MB (`tiny`) to 2.9 GB (`large-v3`). See the [Models](models.md) table.

## Does it work with Bluetooth headphones?

Yes. Murmur uses whatever input device macOS reports as default. AirPods, Sony WH-1000XM5, Shokz — all fine. Bluetooth's narrowband codec hurts accuracy on noisy connections, though; a wired mic is always better.

## Does it cost anything?

No. MIT-licensed open source. The Homebrew tap and the GitHub releases are free. No optional paid tier, no telemetry-funded freemium.

## Does it run during meetings or take over my mic?

No. Other apps (Zoom, Meet, Slack huddles) hold the mic with exclusive sessions. macOS shares the mic between apps in most configurations, but Murmur will not interrupt a call. It opens the mic only when you press its hotkey.

## Where are my files?

| What | Where |
|---|---|
| Config | `~/Library/Application Support/Murmur/config.json` |
| Models | `~/Library/Application Support/Murmur/Models/` |
| History (opt-in) | `~/Library/Application Support/Murmur/history.jsonl` |
| Logs | `~/Library/Logs/Murmur/murmur-YYYY-MM-DD.log` |
| Temp audio | `~/Library/Caches/Murmur/` (deleted on success) |

Full data-flow on [Privacy](privacy.md).

## Can I script it / use it without the menubar?

Yes. The app bundle exposes a small CLI:

```bash
/Applications/Murmur.app/Contents/MacOS/Murmur --help
/Applications/Murmur.app/Contents/MacOS/Murmur --transcribe-only path/to/audio.wav
/Applications/Murmur.app/Contents/MacOS/Murmur --record-once
/Applications/Murmur.app/Contents/MacOS/Murmur --version
```

`--transcribe-only` runs headlessly and prints the transcript to stdout. `--record-once` does one full dictation cycle and exits.

## Per-app prompt profile? { #per-app-prompt }

Planned. Today the profile is global. Track [Settings](settings.md#prompts) for the rollout.

## How do I uninstall?

```bash
brew uninstall --cask murmur            # or drag Murmur.app to the Trash
rm -rf "$HOME/Library/Application Support/Murmur"
rm -rf "$HOME/Library/Caches/Murmur"
rm -rf "$HOME/Library/Logs/Murmur"
tccutil reset Microphone com.murmur.app
tccutil reset Accessibility com.murmur.app
```

That removes every file Murmur ever wrote.
