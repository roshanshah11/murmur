# Technical Architecture

## 1. Architecture overview

Flow Lite is a local macOS utility with five main subsystems:

```text
Global Trigger / Menu
        ↓
Audio Recorder
        ↓
Local Transcription Runtime
        ↓
Cleanup / Formatting Pipeline
        ↓
Text Insertion
```

v0 implementation choice:

```text
Swift menubar app
+ AVFoundation recorder
+ whisper.cpp CLI sidecar
+ rule-based cleaner
+ NSPasteboard + CGEvent paste
```

## 2. Data flow

```text
User presses F6
→ HotkeyMonitor toggles recording
→ AudioRecorder writes temp WAV
→ WhisperRunner invokes local whisper-cli
→ transcript text is read
→ TextCleaner applies conservative cleanup
→ PasteboardInserter copies output
→ PasteboardInserter emits Cmd+V
→ temp audio/transcript are deleted unless debug mode is enabled
```

## 3. Component responsibilities

### AppState

Owns global state:

- idle
- recording
- transcribing
- pasting
- error

Responsibilities:

- coordinate transitions
- avoid overlapping dictations
- surface errors
- log important events

### HotkeyMonitor

Responsibilities:

- listen for F6 in v0
- call start/stop actions
- tolerate permission failure
- allow menu fallback

v1 improvement:

- configurable global shortcut
- hold-to-talk mode
- keyboard event tap rather than passive monitor

### AudioRecorder

Responsibilities:

- request/check microphone permission
- start local WAV recording
- stop recording
- return audio file URL
- clean up temp files

Default format:

- 16 kHz sample rate
- mono
- 16-bit PCM
- WAV container

### WhisperRunner

Responsibilities:

- validate local binary exists
- validate model exists
- execute whisper CLI
- capture timeout/failure
- read transcript output
- return raw transcript

Recommended command shape:

```bash
whisper-cli \
  -m /path/to/model.bin \
  -f /tmp/flow-lite/input.wav \
  -l en \
  -nt \
  -otxt \
  -of /tmp/flow-lite/output
```

### TextCleaner

Responsibilities:

- trim whitespace
- remove common fillers conservatively
- normalize repeated spaces
- apply custom vocabulary
- optionally add terminal punctuation
- preserve raw transcript mode

v1/v2 improvement:

- style modes
- local LLM rewrite
- custom command parsing

### PasteboardInserter

Responsibilities:

- preserve previous clipboard string if configured
- write final text to clipboard
- simulate `Cmd+V`
- optionally restore clipboard later
- fail safely by leaving output copied

### ConfigManager

Responsibilities:

- create config if missing
- read/write JSON config
- expose paths and flags
- validate config at startup

## 4. Process boundaries

v0 uses `whisper.cpp` as an external process rather than embedding it as a library.

Why:

- faster to build
- easier to update independently
- avoids C/C++/Swift bridging complexity
- easier to debug with command-line reproduction

Downside:

- process startup overhead
- file-based audio pipeline instead of streaming
- less control over partial output

Migration path:

```text
v0: whisper-cli external process
v1: long-lived whisper server/daemon or named pipe
v2: embedded C API / Swift wrapper
```

## 5. Platform APIs

### Microphone/audio

Use AVFoundation for capture and audio recording.

### Global shortcut

v0 options:

- `NSEvent.addGlobalMonitorForEvents` for a simple passive monitor
- menu action fallback

v1 options:

- event tap with `CGEvent.tapCreate`
- Carbon RegisterEventHotKey
- dedicated shortcut library if using AppKit/Tauri

### Text insertion

v0:

- `NSPasteboard.general`
- `CGEvent` to simulate `Cmd+V`

v1/v2:

- Accessibility API focused element support
- direct text replacement where reliable
- selected text replacement

### App context

v0:

- `NSWorkspace.shared.frontmostApplication?.localizedName`

v1:

- bundle identifier
- active app category mapping
- optional selected text

v2:

- focused AX element
- nearby text from accessibility tree
- user-approved context capture

## 6. Runtime dependencies

Required:

- macOS 13+
- Swift 5.9+
- local `whisper.cpp` binary
- local GGML model file

Optional later:

- local LLM server such as Ollama/llama.cpp
- launch agent for auto-start
- app signing/notarization

## 7. Directory layout

```text
~/.flow-lite/
  config.json
  logs/
    flow-lite.log
  temp/
    current.wav
    current.txt
  vocabulary.json
```

Implementation layout:

```text
implementation/
  Package.swift
  Sources/FlowLite/
    main.swift
    AppState.swift
    AudioRecorder.swift
    WhisperRunner.swift
    TextCleaner.swift
    PasteboardInserter.swift
    HotkeyMonitor.swift
  Resources/
    config.example.json
  Scripts/
    bootstrap_whisper_cpp.sh
    run_local_smoke_test.sh
  Tests/FlowLiteTests/
    TextCleanerTests.swift
```

## 8. Error handling model

Every pipeline stage returns either success or a typed error:

```text
recordingPermissionDenied
recordingFailed(reason)
missingWhisperBinary(path)
missingModel(path)
transcriptionTimedOut(seconds)
transcriptionFailed(stderr)
emptyTranscript
pasteFailed(reason)
```

User-visible errors should be short. Logs can contain details.

## 9. Logging

v0 logs to stdout and optionally `~/.flow-lite/logs/flow-lite.log`.

Log fields:

- timestamp
- state transition
- active app name
- audio duration
- model path basename
- transcription duration
- cleanup duration
- paste outcome
- error details

Avoid logging transcript content by default.

## 10. Performance budget

For short dictations:

```text
Start recording: <300 ms
Stop recording: <100 ms
Whisper process startup: variable
Transcription: model-dependent
Cleanup: <100 ms
Clipboard paste: <500 ms
```

If latency is poor, optimize in this order:

1. Use smaller model.
2. Enable Metal/Core ML acceleration in whisper.cpp.
3. Avoid `medium`/`large` models for short dictation.
4. Keep a long-lived transcription service instead of launching CLI per dictation.
5. Add streaming only after the basic tool is reliable.

## 11. Security architecture

Default:

- no network calls
- no persistent transcript storage
- delete temp audio
- do not read screen text
- do not log content

Permissions needed:

- Microphone
- Accessibility/Input Monitoring for global shortcut and paste reliability

Risky permissions must be justified in onboarding copy.

## 12. Recommended implementation order

1. Build and test `AudioRecorder` standalone.
2. Build and test `WhisperRunner` using a sample WAV.
3. Build `TextCleaner` with unit tests.
4. Build `PasteboardInserter` and test in TextEdit.
5. Wire into `AppState`.
6. Add menubar UI.
7. Add hotkey.
8. Add config and logs.
9. Add smoke test script.
10. Package as `.app` later.
