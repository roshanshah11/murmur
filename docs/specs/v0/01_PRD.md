# Product Requirements Document — Flow Lite

## 1. Product summary

Flow Lite is a Mac-first, local-first dictation utility for personal use. It lets the user press a global shortcut, speak naturally, locally transcribe the audio, optionally clean up filler words and punctuation, then paste the result into the current cursor location in any active app.

The product is intentionally narrow: **fast private speech-to-text anywhere on macOS**. It should feel like a system utility, not a document editor.

## 2. Problem

Native macOS dictation is convenient but often fails on:

- Long-form speech
- Names, finance/technical vocabulary, and custom terms
- Natural filler-heavy speech
- Formatting for email, Slack, notes, code comments, and prompts
- User trust around where audio/text goes

Commercial tools solve much of this, but a personal local-first alternative should provide enough utility without external dependencies or retention concerns.

## 3. Target user

Primary user: technically comfortable Mac user who writes a lot across apps and wants faster input without sending audio/transcripts to a third-party service.

Example usage contexts:

- Writing emails
- Drafting Slack/Discord/iMessage replies
- Brain-dumping into Notes, Notion, Google Docs, or ChatGPT
- Dictating prompts into Claude/Cursor/ChatGPT
- Capturing rough thoughts while coding
- Writing outreach follow-ups, research notes, and task updates

## 4. Product goals

### v0 goals

1. Record audio with one obvious shortcut or menu action.
2. Save audio locally to a temporary file.
3. Transcribe locally with a local Whisper runtime.
4. Clean obvious filler and spacing mistakes without changing meaning.
5. Paste final text at the active cursor location.
6. Keep no permanent audio/transcript history by default.
7. Make setup debuggable with explicit config paths and logs.

### v1 goals

1. Menubar app with clear idle/recording/transcribing states.
2. Configurable shortcut.
3. Configurable model path and whisper binary path.
4. Custom vocabulary replacement file.
5. App-style presets: email, chat, notes, code comment, raw transcript.
6. Failure recovery: copy output to clipboard if paste fails.
7. Latency improvements and model tuning.

### v2 goals

1. Optional local LLM cleanup.
2. Better active app detection.
3. Selected-text replacement.
4. Context-limited rewrite using current app name and selected text.
5. Streaming partial transcription if needed.
6. Proper app bundle, signing, notarization, and update flow.

## 5. Non-goals

For the first version, the app should not attempt to:

- Fully clone Wispr Flow
- Stream audio to cloud transcription services
- Store dictation history by default
- Build a collaboration/team product
- Support Windows, iOS, Android, or browser extensions
- Read full on-screen content by default
- Implement perfect context awareness across every app
- Auto-send messages or emails

## 6. User experience principles

1. **Low friction:** no separate editor; output goes where the cursor already is.
2. **Local by default:** audio, transcript, and cleanup should stay on the device unless the user explicitly opts in later.
3. **Fast enough beats perfect:** sub-4-second turnaround for short dictations is more valuable than heavyweight rewriting.
4. **Meaning preservation:** cleanup must not invent facts, polish beyond intent, or change names/amounts.
5. **Recoverable:** if insertion fails, final text should remain available in the clipboard or temporary output.
6. **Transparent:** the user should know whether the app is recording, transcribing, pasting, or failed.

## 7. Functional requirements

### FR1 — Global trigger

- User can start and stop dictation without focusing the app.
- v0 default: F6 toggle recording.
- v1: configurable shortcut, including hold-to-talk mode.
- App shows recording state in menu bar.

Acceptance criteria:

- Pressing the shortcut starts recording within 300 ms.
- Pressing the shortcut again stops recording and starts transcription.
- If the shortcut cannot be registered, the menu bar Start/Stop action still works.

### FR2 — Audio recording

- App records microphone input as local WAV.
- Default format: 16 kHz, mono, 16-bit PCM.
- Temporary audio file is deleted after successful transcription unless debug mode is enabled.

Acceptance criteria:

- A 10-second dictation produces a readable WAV file.
- Recording stops cleanly on shortcut, menu click, or app quit.
- App warns if microphone permission is denied.

### FR3 — Local transcription

- App invokes a local transcription runtime.
- v0 recommended runtime: `whisper.cpp` CLI sidecar.
- User supplies binary path and model path in config.
- App reads transcript from generated output file or standard output.

Acceptance criteria:

- Short dictation transcribes without network access.
- Missing binary/model errors produce actionable messages.
- App supports at least `base.en`, `small.en`, and `medium.en` GGML models if available locally.

### FR4 — Text cleanup

- v0 uses conservative local cleanup:
  - remove common fillers only when standalone words
  - normalize whitespace
  - basic capitalization
  - optional sentence punctuation if absent
- v1 supports custom replacements:
  - `caju` → `Caju.ai`
  - `cofounders capital` → `Cofounders Capital`
  - `element four fifty one` → `Element451`

Acceptance criteria:

- Cleanup does not introduce facts.
- Raw transcript mode bypasses cleanup.
- Custom vocabulary can be disabled.

### FR5 — Text insertion

- v0 insertion method: write final text to pasteboard and simulate `Cmd+V`.
- App optionally restores previous clipboard contents after a delay.
- If paste fails, app leaves final text in clipboard and shows a notification.

Acceptance criteria:

- Works in TextEdit, Notes, Chrome text boxes, Gmail compose, Slack/Discord input, VS Code/Cursor editor, and ChatGPT input.
- Failure does not lose output.

### FR6 — Menubar controls

Menu items:

- Start/Stop Dictation
- Open Config
- Open Logs
- Test Whisper Setup
- Toggle Raw Transcript Mode
- Toggle Debug Retain Audio
- Quit

Acceptance criteria:

- User can operate app entirely from menu if shortcut fails.
- State label updates correctly.

### FR7 — Privacy controls

- Default: delete temp audio and transcript after insertion.
- No network calls in v0.
- No analytics.
- No crash-report upload.
- Debug mode must be explicit.

Acceptance criteria:

- Running with network off does not affect dictation.
- Temp files are removed after normal completion.
- Config documents retention behavior.

## 8. Non-functional requirements

### Latency

Target for 10-second dictation on Apple Silicon:

- Recording start: <300 ms
- Stop-to-transcript: 1–5 seconds depending on model
- Cleanup: <100 ms for rule-based cleanup
- Paste: <500 ms

### Reliability

- The app should never discard a transcript until it has either pasted or copied it to clipboard.
- Crashes during transcription should preserve temp output in debug mode.
- Missing permissions should be detected and reported.

### Privacy

- v0 must function offline.
- Audio/transcript files should be stored in a temp directory.
- No persistent history by default.

### Maintainability

- Runtime paths are config-driven.
- Components are isolated:
  - audio recording
  - transcription runtime
  - cleanup
  - insertion
  - hotkey/menu

## 9. Success metrics

For personal use, measure:

1. Median stop-to-paste latency.
2. Number of successful pastes / total dictations.
3. Manual edits needed after paste.
4. Frequency of transcription failures.
5. Frequency of permission-related issues.
6. Whether user actually keeps using it daily.

## 10. MVP definition

The MVP is complete when the user can:

1. Start the app from Terminal or a built executable.
2. Press F6 while focused in another app.
3. Speak for 5–30 seconds.
4. Press F6 again.
5. See cleaned text pasted into the active field.
6. Repeat this for at least 20 dictations without app restart.

## 11. Recommended first milestone

Build the implementation in this order:

1. CLI proof: record WAV, run local Whisper, print transcript.
2. Paste proof: set clipboard and simulate `Cmd+V`.
3. Menubar app: start/stop recording manually.
4. F6 global trigger.
5. Cleanup pipeline.
6. Config file.
7. Error handling and logs.
8. Smoke tests.
