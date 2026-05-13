# Implementation Prompts

Use these prompts with Claude Code, Codex, or another coding agent. They assume this repository structure and the PRD files in this bundle.

## Prompt 1 — Build the v0 audio recorder

```text
Read the PRD files in this folder, especially 01_PRD.md, 03_Technical_Architecture.md, and implementation/README.md.

Implement the AudioRecorder component for the Swift macOS FlowLite executable.

Requirements:
- Use AVFoundation.
- Request/check microphone permission.
- Record to a temp WAV file.
- Use 16 kHz, mono, 16-bit PCM if possible.
- Expose startRecording() and stopRecording() async/sync methods appropriate for the app.
- Return the recorded file URL.
- Do not upload or persist audio by default.
- Add clear errors for permission denied and recorder failure.

After implementation:
- Run swift build.
- Add a simple manual test command if useful.
- Do not add unrelated features.
```

## Prompt 2 — Implement WhisperRunner

```text
Implement WhisperRunner for FlowLite.

Requirements:
- Read whisperBinaryPath, modelPath, language, and timeout from Config.
- Validate the binary exists and is executable.
- Validate the model exists.
- Use Process with executableURL and arguments array. Do not use /bin/sh -c.
- Invoke whisper-cli with model, audio file, language, no timestamps, txt output.
- Capture stderr/stdout.
- Read output txt file.
- Return a non-empty raw transcript string.
- Throw typed errors for missing binary, missing model, nonzero exit, timeout, and empty transcript.
- Never log transcript content by default.

Add a smoke-test script or CLI mode if needed.
```

## Prompt 3 — Implement TextCleaner and tests

```text
Implement TextCleaner and unit tests.

Requirements:
- Clean conservatively.
- Trim whitespace.
- Collapse repeated spaces.
- Remove standalone filler words: um, uh, er, ah.
- Be careful with "like" and "you know"; only remove if clearly filler.
- Apply custom vocabulary replacements case-insensitively as phrase matches.
- Capitalize the first character of the final text.
- Add terminal punctuation only when text ends without ., ?, !, :, or ;.
- Support rawTranscriptMode that bypasses cleanup except trim.

Write tests for:
- filler removal
- custom vocabulary
- raw mode
- punctuation
- no accidental number change
```

## Prompt 4 — Implement paste insertion

```text
Implement PasteboardInserter.

Requirements:
- Copy final text to NSPasteboard.
- Simulate Cmd+V using CGEvent.
- Do not discard text if paste fails.
- Default restoreClipboardAfterPaste should be false.
- If restoreClipboardAfterPaste is true, preserve previous string clipboard content in memory only and restore after configurable delay.
- Do not log clipboard contents.
- Add clear comments explaining why clipboard paste is used for v0.
```

## Prompt 5 — Wire end-to-end state machine

```text
Wire AudioRecorder, WhisperRunner, TextCleaner, and PasteboardInserter into AppState.

Requirements:
- States: idle, recording, transcribing, pasting, error.
- Prevent concurrent dictations.
- Start dictation from menu/hotkey.
- Stop dictation and run pipeline.
- Ensure temp files are cleaned up on success unless debugRetainAudio is true.
- Ensure the app returns to idle after success/failure.
- Show user-visible error messages through menu or notification.
- Do not add cloud calls.
```

## Prompt 6 — Menubar and hotkey

```text
Implement the macOS menubar UI and F6 toggle.

Requirements:
- Use NSStatusItem.
- Menu shows current state.
- Menu supports Start/Stop Dictation, Raw Transcript Mode toggle, Open Config, Open Logs, Test Whisper Setup, Quit.
- Add F6 global monitor for v0.
- Debounce repeated key events.
- If global monitor fails or permissions are missing, menu controls must still work.
- Do not read screen content for v0.
```

## Prompt 7 — Reliability audit

```text
Audit FlowLite against the PRD and test plan.

Check specifically:
- no network calls
- no shell string execution
- no transcript logging by default
- temp audio deletion by default
- missing model/binary errors are clear
- output is copied before paste
- concurrent dictation is blocked
- app returns to idle on failure
- 20 repeated dictations can run without restart

Make minimal targeted fixes. Do not rewrite the architecture unless necessary.
```

## Prompt 8 — Build packaging notes

```text
Create build and run documentation for FlowLite.

Include:
- installing/building whisper.cpp locally
- downloading a GGML model
- setting config.json paths
- running swift build
- running swift run FlowLite
- granting microphone and accessibility permissions
- manual smoke test in TextEdit
- common errors and fixes

Do not link to implementation code; include exact local file paths and commands.
```
