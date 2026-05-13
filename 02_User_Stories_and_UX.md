# User Stories and UX Spec

## 1. Core user stories

### Story 1 — Dictate into any text field

As a user, I want to press a shortcut, speak, and have the final text appear where my cursor is, so I can write faster without switching apps.

Acceptance criteria:

- Works in at least one browser text field, one native macOS text editor, and one chat app.
- Does not require opening a separate document editor.
- If the final paste fails, the text is still on the clipboard.

### Story 2 — Private local transcription

As a user, I want dictation to work without network access, so audio and transcripts are not sent to a third party.

Acceptance criteria:

- App can transcribe in airplane mode/offline network state.
- App shows a clear error only if the local model or binary is missing.

### Story 3 — Natural speech cleanup

As a user, I want filler words removed and punctuation cleaned, so my spoken notes are usable without heavy editing.

Acceptance criteria:

- Removes obvious filler like “um,” “uh,” “you know,” and “like” when standalone.
- Does not rewrite meaning or add unsupported claims.
- Raw mode is available when exact transcript is desired.

### Story 4 — Custom terms

As a user, I want finance, school, project, and name-specific terms recognized or corrected, so I do not need to retype proper nouns.

Acceptance criteria:

- A simple dictionary file supports phrase replacement.
- Replacement rules can be reviewed and edited manually.
- The cleanup system should preserve case-sensitive terms.

### Story 5 — Failure recovery

As a user, I want the app to fail safely, so I do not lose dictated content.

Acceptance criteria:

- Transcript is copied to clipboard before any paste attempt.
- User gets a notification if paste may not have succeeded.
- Debug logs describe which step failed.

## 2. UX states

### Idle

Menu bar icon: neutral.

Menu label: `Flow Lite: Idle`.

Allowed actions:

- Start Dictation
- Test Whisper Setup
- Open Config
- Quit

### Recording

Menu bar icon: recording state.

Menu label: `Flow Lite: Recording…`.

Allowed actions:

- Stop Dictation
- Cancel Dictation
- Quit, with confirmation later in v1

### Transcribing

Menu bar icon: processing state.

Menu label: `Flow Lite: Transcribing…`.

Allowed actions:

- Cancel if process is running too long
- Open logs

### Pasting

Menu label: `Flow Lite: Pasting…`.

Behavior:

- App sets clipboard to final text.
- App simulates `Cmd+V`.
- App optionally restores prior clipboard contents.

### Error

Menu label examples:

- `Microphone permission denied`
- `Whisper binary not found`
- `Model file missing`
- `No focused app detected`
- `Paste failed — copied to clipboard`

Errors should be actionable, not generic.

## 3. Primary flows

### Flow A — First run

1. User launches app.
2. App checks config exists.
3. If missing, app creates `~/.flow-lite/config.json` from defaults.
4. App checks microphone permission.
5. App checks local Whisper binary and model paths.
6. App shows setup status in menu.

Minimum acceptable v0 behavior: log setup problems and show menu item that opens the config.

### Flow B — Normal dictation

1. User places cursor in a text field.
2. User presses F6.
3. App starts recording.
4. User speaks.
5. User presses F6.
6. App stops recording.
7. App runs local transcription.
8. App cleans transcript.
9. App copies final text to pasteboard.
10. App simulates `Cmd+V`.
11. App deletes temp files unless debug mode is enabled.
12. App returns to idle.

### Flow C — Raw transcript

1. User toggles Raw Transcript Mode.
2. Dictation bypasses cleanup.
3. Final transcript is pasted exactly as returned by Whisper, except for safe whitespace trimming.

### Flow D — Paste failure

1. Dictation completes.
2. App copies final text to clipboard.
3. Paste event fails or target app blocks paste.
4. App keeps text on clipboard.
5. App shows notification: `Paste may have failed. Text is copied to clipboard.`

### Flow E — Missing Whisper setup

1. User dictates.
2. Recording completes.
3. Transcription attempts to run.
4. App detects missing binary/model.
5. App does not discard audio in debug mode.
6. App shows exact missing path.

## 4. Menubar design

Menu structure:

```text
Flow Lite: Idle
────────────────
Start Dictation        F6
Raw Transcript Mode    Off
Debug Retain Audio     Off
────────────────
Test Whisper Setup
Open Config
Open Logs
────────────────
Quit
```

Recording menu:

```text
Flow Lite: Recording…
────────────────
Stop Dictation         F6
Cancel Dictation
────────────────
Quit
```

## 5. Permission UX

### Microphone

Message:

```text
Flow Lite needs microphone access to record dictation audio.
```

Recovery:

- Open System Settings → Privacy & Security → Microphone.

### Accessibility / Input monitoring

Needed for reliable global shortcuts and simulated paste.

Message:

```text
Flow Lite needs Accessibility permission to detect the global shortcut and paste text into the active app.
```

Recovery:

- Open System Settings → Privacy & Security → Accessibility.

## 6. Configuration UX

Config path:

```text
~/.flow-lite/config.json
```

Example settings:

```json
{
  "whisperBinaryPath": "/Users/roshan/dev/whisper.cpp/build/bin/whisper-cli",
  "modelPath": "/Users/roshan/models/ggml-base.en.bin",
  "language": "en",
  "rawTranscriptMode": false,
  "restoreClipboardAfterPaste": false,
  "deleteTempAudio": true,
  "debugRetainAudio": false,
  "customVocabulary": {
    "cofounders capital": "Cofounders Capital",
    "caju dot ai": "Caju.ai",
    "element four fifty one": "Element451"
  }
}
```

## 7. UX decisions for v0

| Decision | Choice | Reason |
|---|---|---|
| Trigger | F6 toggle | Simpler than hold-to-talk and easier to test |
| Insertion | Clipboard + `Cmd+V` | Most reliable across apps for MVP |
| Context | Active app name only | Avoid premature Accessibility-tree complexity |
| Cleanup | Rule-based | Local, deterministic, low latency |
| Retention | Delete by default | Matches local-first privacy goal |
| History | No history | Reduces privacy/security surface |

## 8. Future UX enhancements

- Hold-to-talk mode.
- Floating recording pill.
- Dictation history with encrypted local storage.
- Per-app style profiles.
- Prompt commands: “make this concise,” “turn this into an email,” “format as bullets.”
- Selected-text replacement.
- Local-only command grammar.
