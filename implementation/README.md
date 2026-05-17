# FlowLite Implementation

Swift macOS menubar dictation utility. Local-first, no network calls. Targets macOS 13+.

## What this implementation does

- Runs as a macOS menubar utility.
- Monitors the `fn` (Globe) key globally and triggers on double-tap.
- Probes Accessibility / Input Monitoring permission on launch and surfaces a menu hint if missing.
- Records microphone audio via AVFoundation to a temporary WAV file.
- Spawns a local `whisper-cli` binary per dictation to transcribe.
- Applies conservative rule-based cleanup (filler removal, terminal period for ≥3-token sentences).
- Copies cleaned text to the clipboard and simulates `Cmd+V` to paste into the focused app.
- Pauses Spotify / Apple Music if playing and mutes system output while recording, so playback doesn't bleed into the mic. Restores volume and resumes the music app on completion.
- Shows a notch-anchored overlay (animated spectrum bars + state pill) while recording, transcribing, and on the success flash.
- Persists a local transcription history under `~/.flow-lite/history/` (viewable from the menubar).
- Writes a dated file log to `~/.flow-lite/logs/`. Transcripts are never logged.
- Exposes a `--transcribe-only <wav>` CLI mode for headless testing.

## What this implementation does not do

- Does not stream partial transcripts.
- Does not store dictation history.
- Does not use a cloud LLM.
- Does not read the Accessibility tree of the focused app.
- Does not bundle `whisper.cpp` binaries — bootstrap script builds them.

## Setup

Three commands, in order:

```bash
bash Scripts/bootstrap_whisper_cpp.sh
bash Scripts/build_app.sh
open build/FlowLite.app
```

The bootstrap script clones whisper.cpp, builds it with Metal, downloads `ggml-small.en-q5_1.bin`, and writes a default `~/.flow-lite/config.json`.

## Project layout

Files under `Sources/FlowLite/`:

| File | Purpose |
|---|---|
| `main.swift` | Entry point. Dispatches to CLI mode or starts the AppKit app. |
| `AppState.swift` | Pipeline coordinator: idle → recording → transcribing → pasting. |
| `AppContext.swift` | Resolves the focused app name and bundle id for context-aware behavior. |
| `AudioRecorder.swift` | AVFoundation microphone capture to 16 kHz mono WAV. |
| `WhisperRunner.swift` | Spawns `whisper-cli`, parses stdout, enforces timeout. |
| `TextCleaner.swift` | Rule-based cleanup: filler removal, conservative punctuation, custom vocabulary substitution. |
| `PasteboardInserter.swift` | Clipboard write and simulated `Cmd+V`. |
| `HotkeyMonitor.swift` | Global `fn` key monitor with double-tap detection. |
| `Config.swift` | Loads and validates `~/.flow-lite/config.json`. |
| `Log.swift` | Dated file logger to `~/.flow-lite/logs/`. |
| `Notifier.swift` | User-facing notifications and menu state updates. |
| `VolumeController.swift` | Pauses Spotify / Music (if playing) and mutes system output during recording; restores both on completion. |
| `HistoryStore.swift` | Append-only JSON log of past transcripts under `~/.flow-lite/history/`. |
| `NotchIndicator.swift` | Notch-anchored overlay window: morphing pill states (idle → recording → transcribing → success). |
| `SpectrumBarsView.swift` | CALayer-based animated equalizer used inside the notch pill while recording. |
| `CLI.swift` | Argument parsing for `--transcribe-only`, `--record-once`, `--help`, `--version`. |

## Configuration

Shape lives at `Resources/config.example.json`. Copy to `~/.flow-lite/config.json` and edit paths:

```json
{
  "whisperBinaryPath": "~/dev/whisper.cpp/build/bin/whisper-cli",
  "modelPath": "~/models/ggml-small.en-q5_1.bin",
  "language": "en",
  "rawTranscriptMode": false,
  "restoreClipboardAfterPaste": false,
  "clipboardRestoreDelayMs": 1500,
  "deleteTempAudio": true,
  "debugRetainAudio": false,
  "transcriptionTimeoutSeconds": 60,
  "whisperThreads": null,
  "pasteDelayMs": 50,
  "errorAutoClearSeconds": 3,
  "customVocabulary": {
    "caju ai": "Caju.ai"
  }
}
```

## Permissions

FlowLite needs three macOS permissions:

- **Microphone** — for AVFoundation audio capture. Prompted on first record.
- **Accessibility / Input Monitoring** — for the global `fn` monitor and simulated `Cmd+V`. Granted manually in **System Settings → Privacy & Security → Accessibility**.
- **Automation** — for AppleScript control of system volume and Spotify / Music (pause on record-start, resume on completion). Prompted the first time each target is touched; approve once and macOS remembers.

If Accessibility is not granted, the menubar shows **⚠ Grant Accessibility Permission** as the top menu item; clicking it opens the relevant settings pane.

## Common errors and fixes

| Symptom | Fix |
|---|---|
| `Whisper binary not found` | Run `bash Scripts/bootstrap_whisper_cpp.sh`, or fix `whisperBinaryPath` in `~/.flow-lite/config.json`. |
| `Whisper model missing` | Run the bootstrap script, or fix `modelPath` in the config. |
| `Mic permission denied` | **System Settings → Privacy & Security → Microphone** → enable FlowLite. |
| `fn double-tap not working` | Disable Apple Dictation (**System Settings → Keyboard → Dictation → Off**). Confirm Accessibility permission is granted. |
| Paste lands in the wrong app | Place the cursor in the target field **before** the first double-tap. The focused app at recording-start is the paste target. |

## Tests

```bash
swift test
```

Note: `swift test` requires a full **Xcode.app** install, not just Command Line Tools. CLT 6.3 toolchains have a SwiftPM manifest link bug that breaks test target linking. If `xcode-select -p` points at `/Library/Developer/CommandLineTools`, switch with:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Smoke test

End-to-end latency benchmark against a fixed sample WAV, 20 iterations, prints median and p95 ms:

```bash
bash Scripts/run_local_smoke_test.sh
```
