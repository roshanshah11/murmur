# Engineering Task Breakdown

## Milestone 0 — Repo scaffold

Goal: Create a runnable Swift executable that can start as a macOS utility.

Tasks:

- [ ] Create Swift Package.
- [ ] Add executable target `FlowLite`.
- [ ] Add files for state, recording, transcription, cleanup, paste, hotkey.
- [ ] Add example config.
- [ ] Add scripts directory.

Acceptance:

- `swift build` succeeds.
- `swift run FlowLite --help` or app launch does not crash.

## Milestone 1 — Audio recording proof

Goal: Record microphone input to WAV.

Tasks:

- [ ] Request microphone permission.
- [ ] Start recording to temp WAV.
- [ ] Stop recording.
- [ ] Print saved file path.
- [ ] Validate file has nonzero size.

Acceptance:

- 5-second recording produces a playable WAV.
- Permission denial shows clear message.

## Milestone 2 — Whisper runtime proof

Goal: Transcribe an existing WAV using local `whisper.cpp`.

Tasks:

- [ ] Add config loading for binary/model path.
- [ ] Validate binary path exists.
- [ ] Validate model path exists.
- [ ] Run `whisper-cli` via `Process`.
- [ ] Read transcript file.
- [ ] Capture stderr for errors.

Acceptance:

- Sample WAV transcribes from command line.
- Missing model path gives exact error.
- No shell string is used.

## Milestone 3 — Cleanup pipeline

Goal: Convert raw transcript into minimally usable text.

Tasks:

- [ ] Trim whitespace.
- [ ] Remove filler words conservatively.
- [ ] Normalize spaces.
- [ ] Apply vocabulary replacements.
- [ ] Add capitalization.
- [ ] Add unit tests.

Acceptance:

- Unit tests cover filler removal and custom vocabulary.
- Raw mode bypasses cleanup.

## Milestone 4 — Paste proof

Goal: Paste text into another app.

Tasks:

- [ ] Write output to `NSPasteboard`.
- [ ] Emit `Cmd+V` with `CGEvent`.
- [ ] Test in TextEdit.
- [ ] Add fallback notification/log.

Acceptance:

- Running a test command pastes text into TextEdit.
- If paste fails, output remains on clipboard.

## Milestone 5 — End-to-end CLI flow

Goal: One command records, transcribes, cleans, and pastes.

Tasks:

- [ ] Add state coordinator.
- [ ] Wire recorder → transcriber → cleaner → paste.
- [ ] Add `--record-once` mode.
- [ ] Add debug retention flag.

Acceptance:

- User can run app, trigger one recording, and paste output.

## Milestone 6 — Menubar app

Goal: Control app from macOS menu bar.

Tasks:

- [ ] Create `NSStatusItem`.
- [ ] Add Start/Stop menu item.
- [ ] Add Open Config menu item.
- [ ] Add Quit item.
- [ ] Update menu title by state.

Acceptance:

- Menu bar shows idle/recording/transcribing states.
- Start/Stop works without Terminal input.

## Milestone 7 — Global shortcut

Goal: Toggle recording from anywhere.

Tasks:

- [ ] Add F6 global monitor.
- [ ] Detect key down once per press.
- [ ] Debounce repeated key events.
- [ ] Fall back to menu if monitoring fails.

Acceptance:

- Pressing F6 starts/stops dictation while another app is focused.
- No duplicate toggles from key repeat.

## Milestone 8 — Reliability pass

Goal: Make failure modes safe.

Tasks:

- [ ] Prevent concurrent dictations.
- [ ] Stop recording on quit.
- [ ] Add transcription timeout.
- [ ] Ensure output is copied before paste.
- [ ] Clean temp files on launch.
- [ ] Add smoke test script.

Acceptance:

- 20 consecutive dictations do not require restart.
- Missing model/binary errors do not crash app.
- Failed paste leaves text on clipboard.

## Milestone 9 — Personal polish

Goal: Make it usable daily.

Tasks:

- [ ] Add vocabulary file.
- [ ] Add raw transcript toggle.
- [ ] Add notification on completion/failure.
- [ ] Add model latency logging.
- [ ] Add simple onboarding doc.

Acceptance:

- User can configure paths without code changes.
- User can debug common failures without source edits.

## Milestone 10 — Later improvements

Only after v0 works:

- [ ] Hold-to-talk mode.
- [ ] Better keyboard shortcut registration.
- [ ] Active app style presets.
- [ ] Local LLM cleanup.
- [ ] Selected text replacement.
- [ ] App bundle packaging.
- [ ] Code signing/notarization.
- [ ] Launch on login.
- [ ] Encrypted local history.
- [ ] Embedded Whisper library.

## Definition of Done for v0

- [ ] Works offline.
- [ ] Dictates into TextEdit, Notes, Chrome, ChatGPT, and Cursor.
- [ ] Uses local `whisper.cpp` binary.
- [ ] Deletes temp audio by default.
- [ ] Does not log transcript content by default.
- [ ] Has usable config file.
- [ ] Handles missing permissions/binary/model cleanly.
- [ ] Can be run repeatedly without restart.
