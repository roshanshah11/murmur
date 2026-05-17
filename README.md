# FlowLite

## What this is

FlowLite is a local-first macOS menubar dictation utility. It records the microphone, transcribes audio locally via a `whisper.cpp` sidecar, applies conservative text cleanup, and pastes the result into the focused app. No network calls. No accounts. No cloud. Targets macOS 13+ on Apple Silicon (Metal-accelerated) or Intel.

Thesis: **Local-first macOS dictation. Double-tap fn, speak, paste.**

## Trigger

Double-tap the `fn` (Globe) key to start recording. Double-tap again to stop, transcribe, and paste. Single taps are ignored.

### Apple Dictation collision

macOS ships with Apple's built-in Dictation, which by default also listens for a double-tap on `fn`. You must disable it or remap it, otherwise both will fire.

Disable Apple Dictation:

1. Open **System Settings → Keyboard**.
2. Find **Dictation**.
3. Toggle it **Off**.

Or, leave Dictation enabled and change its shortcut to something other than double-tap `fn` from the same panel.

## Setup

Three commands, in order:

```bash
bash Scripts/bootstrap_whisper_cpp.sh
bash Scripts/build_app.sh
open build/FlowLite.app
```

The app is unsigned. On first launch macOS will block it — right-click the `.app` in Finder and choose **Open** to bypass Gatekeeper once.

## First-run checklist

1. Disable Apple Dictation (see above).
2. Launch `FlowLite.app`. Grant **Microphone** permission when prompted.
3. Grant **Accessibility** permission in **System Settings → Privacy & Security → Accessibility** (needed for the global fn monitor and simulated Cmd+V).
4. Click in the app you want to dictate into. Place the cursor where the text should land.
5. Double-tap `fn`.
6. Speak.
7. Double-tap `fn` again. Text pastes at the cursor.

## Paths

| What | Where |
|---|---|
| Config | `~/.flow-lite/config.json` |
| Logs | `~/.flow-lite/logs/flow-lite-YYYY-MM-DD.log` |
| Temp audio | `~/Library/Caches/FlowLite/temp/` |

Temp audio is deleted after a successful transcription. Transcripts are never written to logs.

## CLI modes

The same binary inside `FlowLite.app/Contents/MacOS/FlowLite` accepts:

- `--transcribe-only <path-to-wav>` — headless: transcribe an existing WAV, print cleaned text to stdout, exit.
- `--record-once` — record one dictation cycle without the menubar UI.
- `--help` — print usage.
- `--version` — print version.

## What's in this bundle

| File | Purpose |
|---|---|
| `01_PRD.md` | Product requirements: goals, scope, users, requirements, metrics |
| `02_User_Stories_and_UX.md` | End-to-end user flows, menubar behavior, permissions, edge cases |
| `03_Technical_Architecture.md` | System architecture, data flow, components, technical choices |
| `04_Local_First_Transcription.md` | Whisper runtime strategy, model choice, latency budget |
| `05_Text_Insertion_Context.md` | Clipboard insertion, Accessibility API, app context |
| `06_Data_Privacy_Security.md` | Local-first data policy, threat model, retention, permissions |
| `07_Engineering_Task_Breakdown.md` | Build tasks, milestones, sequencing, acceptance criteria |
| `08_Test_Plan.md` | Manual, automated, latency, privacy, reliability tests |
| `09_Risks_and_Open_Questions.md` | Technical risks, product risks, mitigations |
| `10_Implementation_Prompts.md` | Prompts for Claude/Codex-style implementation workflows |
| `11_Reference_Implementation.md` | Embedded copies of starter implementation files |
| `12_References.md` | Reference sources that shaped the implementation |
| `app/` | Swift macOS source, scripts, tests, and resources |

## Out of scope for v0

- Cloud transcription or cloud LLM cleanup.
- Mobile / iOS keyboard.
- Perfect contextual rewriting across every app.
- Accounts, team settings, cross-device sync.
- Real-time partial streaming.

## Daily use

Iterate on cleanup rules or vocabulary by editing `~/.flow-lite/config.json` and relaunching. To benchmark latency after changes, run:

```bash
bash Scripts/run_local_smoke_test.sh
```

This loops 20 dictations against a fixed sample WAV and reports median and p95 milliseconds end-to-end.
