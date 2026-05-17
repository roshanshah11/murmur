---
title: Architecture
---

# Architecture

Get oriented in the Murmur codebase: module layout, state machine, threading model, and where to read first.

For setup instructions go to [Development](development.md).

## Module map

```mermaid
flowchart TB
    subgraph UI["UI layer (SwiftUI / AppKit)"]
        MenubarController
        SettingsWindow
        HistoryWindow
        NotchOverlay
    end

    subgraph Core["Core"]
        AppCoordinator
        StateMachine
        HotkeyMonitor
        AudioRecorder
        Transcriber
        TextCleaner
        Paster
        Config
    end

    subgraph Sys["System bridges"]
        AVAudioEngine
        WhisperCpp[whisper.cpp]
        Accessibility[CGEvent / AX]
        MediaRemote
        Sparkle
    end

    HotkeyMonitor --> Accessibility
    AudioRecorder --> AVAudioEngine
    Transcriber --> WhisperCpp
    Paster --> Accessibility
    AppCoordinator <--> StateMachine
    MenubarController --> AppCoordinator
    SettingsWindow --> Config
    HistoryWindow --> Config
    NotchOverlay --> StateMachine
    AppCoordinator --> HotkeyMonitor
    AppCoordinator --> AudioRecorder
    AppCoordinator --> Transcriber
    AppCoordinator --> TextCleaner
    AppCoordinator --> Paster
    AppCoordinator -.pause/resume.-> MediaRemote
    AppCoordinator -.update.-> Sparkle
```

## State machine

`MurmurState` is the single source of truth for what's happening at any moment. All UI subscribes to it.

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Arming: hotkey down
    Arming --> Recording: arm complete
    Arming --> Idle: cancel
    Recording --> Stopping: hotkey or silence
    Stopping --> Transcribing: audio finalized
    Transcribing --> Cleaning: whisper.cpp returned
    Cleaning --> Pasting: profile + vocab applied
    Pasting --> Success: paste delivered
    Pasting --> Error: paste failed
    Transcribing --> Error: whisper failed
    Recording --> Error: audio failed
    Success --> Idle: 600 ms hold
    Error --> Idle: banner dismissed
```

Transitions are explicit; there is no implicit fallthrough. Every transition logs its label without the transcript payload.

## Threading model

| Layer | Thread |
|---|---|
| `MenubarController`, `SettingsWindow`, `NotchOverlay` | Main (UI) |
| `HotkeyMonitor` | Main run loop (CGEventTap requires it) |
| `AudioRecorder` | Dedicated `AVAudioSession` thread, audio render priority |
| `Transcriber` | Background `DispatchQueue` labeled `murmur.transcribe`, QoS `userInitiated` |
| `TextCleaner`, `Vocabulary` substitution | Synchronous on the transcribe queue |
| `Paster` | Main thread (Accessibility + clipboard APIs require it) |
| `Sparkle` | Sparkle-owned background queue |

All cross-thread state flows through the `StateMachine`, which serializes mutations on a private serial queue and publishes via Combine. No view directly touches the recorder or the transcriber.

## Key file pointers

| Concern | File |
|---|---|
| App entry point | `app/Sources/Murmur/App/MurmurApp.swift` |
| Coordinator | `app/Sources/Murmur/Core/AppCoordinator.swift` |
| State machine | `app/Sources/Murmur/Core/StateMachine.swift` |
| Global hotkey | `app/Sources/Murmur/Input/HotkeyMonitor.swift` |
| Audio capture | `app/Sources/Murmur/Audio/AudioRecorder.swift` |
| Whisper bridge | `app/Sources/Murmur/Transcription/Transcriber.swift` |
| whisper.cpp wrapper | `Sources/CWhisper/` |
| Text cleanup profiles | `app/Sources/Murmur/Text/TextCleaner.swift` |
| Vocabulary | `app/Sources/Murmur/Text/Vocabulary.swift` |
| Paste path | `app/Sources/Murmur/Paste/Paster.swift` |
| Notch overlay | `app/Sources/Murmur/UI/NotchOverlay.swift` |
| Settings window | `app/Sources/Murmur/UI/Settings/*` |
| History viewer | `app/Sources/Murmur/UI/History/*` |
| Config persistence | `app/Sources/Murmur/Config/Config.swift` |
| Model downloader | `app/Sources/Murmur/Models/ModelDownloader.swift` |
| Sparkle integration | `app/Sources/Murmur/Updates/UpdaterController.swift` |
| Media remote bridge | `app/Sources/Murmur/Media/MediaRemoteController.swift` |
| Logging | `app/Sources/Murmur/Logging/Logger.swift` |
| CLI entry points | `app/Sources/Murmur/CLI/CLI.swift` |

## How to read the codebase

If you've never opened Murmur before, walk it in this order:

1. `MurmurApp.swift` — wires up `AppCoordinator`.
2. `StateMachine.swift` — the contract every other module follows.
3. `HotkeyMonitor.swift` → `AudioRecorder.swift` → `Transcriber.swift` — the happy-path dataflow.
4. `TextCleaner.swift` + `Vocabulary.swift` — pure functions, easiest to read.
5. `Paster.swift` — the trickiest module; clipboard swap-and-restore.
6. `NotchOverlay.swift` — explains the screen-geometry math.

## Tests

Tests live in `Tests/MurmurTests/`. Run with:

```bash
swift test
```

Snapshots for the UI live in `Tests/MurmurTests/Snapshots/` and use `swift-snapshot-testing`.

## Next

- [Development](development.md) for the build + contribution flow.
- [Privacy](privacy.md) for the network surface.
