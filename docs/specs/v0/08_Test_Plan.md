# Test Plan

## 1. Test strategy

The main risk is not only transcription accuracy. The main risks are:

- microphone permission failure
- missing local runtime/model
- event/hotkey failure
- paste failure
- losing dictated text
- unexpected retention of sensitive audio/transcript
- latency becoming annoying

Testing should cover the whole loop, not isolated functions only.

## 2. Unit tests

### TextCleaner tests

Cases:

```text
"um I think this is good" → "I think this is good."
"uh can you send this to caju dot ai" → "Can you send this to Caju.ai."
"cofounders capital is based in north carolina" → "Cofounders Capital is based in north carolina."
"raw transcript mode" bypasses filler removal
```

Test constraints:

- Do not remove “like” when it is likely a verb.
- Do not alter numbers.
- Do not alter capitalization inside replacement values.

### Config tests

Cases:

- missing config creates default
- invalid JSON gives readable error
- missing binary path detected
- missing model path detected

### WhisperRunner tests

Use dependency injection or a fake binary for unit tests.

Cases:

- returns transcript when output file exists
- errors when output file is empty
- captures stderr on nonzero exit
- times out long-running process

## 3. Manual smoke tests

### Smoke test 1 — TextEdit

1. Open TextEdit.
2. Place cursor in a new document.
3. Press F6.
4. Say: `testing one two three`.
5. Press F6.
6. Confirm text appears.

Expected:

```text
Testing one two three.
```

### Smoke test 2 — Chrome web input

1. Open a web text field.
2. Run same test.
3. Confirm paste works.

### Smoke test 3 — ChatGPT prompt box

Say:

```text
help me rewrite this email in a more concise tone
```

Expected:

```text
Help me rewrite this email in a more concise tone.
```

### Smoke test 4 — Gmail compose

Say:

```text
hi daniel just wanted to follow up on the market map i can send the final version tonight
```

Expected:

```text
Hi Daniel just wanted to follow up on the market map i can send the final version tonight.
```

v0 cleanup will not perfect email formatting. That is acceptable.

### Smoke test 5 — Cursor/VS Code

Say:

```text
add a comment explaining that this function validates the local whisper model path
```

Expected:

Text appears in editor. Formatting may need manual edits.

## 4. Permission tests

### Microphone denied

1. Remove microphone permission in System Settings.
2. Start dictation.
3. Confirm clear error.
4. Confirm app does not crash.

### Accessibility denied

1. Remove Accessibility permission.
2. Try shortcut/paste.
3. Confirm menu fallback works.
4. Confirm error explains permission need.

## 5. Runtime path tests

### Missing whisper binary

Set config:

```json
"whisperBinaryPath": "/bad/path/whisper-cli"
```

Expected:

- App reports missing binary.
- Audio is not lost if debug mode is on.
- App returns to idle.

### Missing model

Set config:

```json
"modelPath": "/bad/path/model.bin"
```

Expected:

- App reports missing model.
- No crash.

## 6. Privacy tests

### Offline test

1. Disable Wi-Fi.
2. Quit any VPN/network.
3. Run dictation.
4. Confirm success.

### Temp file deletion test

1. Dictate once.
2. Inspect temp directory.
3. Confirm audio/transcript removed if debug disabled.

### Log content test

1. Dictate sensitive phrase.
2. Open logs.
3. Confirm phrase is not present.

## 7. Latency tests

Record:

| Dictation length | Model | Stop-to-transcript | Stop-to-paste | Notes |
|---:|---|---:|---:|---|
| 5 sec | base.en | | | |
| 10 sec | base.en | | | |
| 30 sec | base.en | | | |
| 10 sec | small.en | | | |
| 30 sec | small.en | | | |

Target:

- Short dictation should feel near-instant.
- Long dictation can take longer if state is visible.

## 8. Reliability soak test

Run 20 dictations in a row:

- 5 into TextEdit
- 5 into Chrome
- 5 into ChatGPT
- 5 into Cursor

Track:

- failures
- duplicates
- missing pastes
- app hangs
- keyboard shortcut misses
- latency spikes

Pass criteria:

- 18/20 successful pastes minimum for v0.
- 20/20 transcripts copied to clipboard minimum.
- No app restart required.

## 9. Regression checklist

Run before each daily-use build:

- [ ] `swift build` succeeds.
- [ ] TextCleaner tests pass.
- [ ] Whisper setup test passes.
- [ ] TextEdit paste works.
- [ ] Chrome paste works.
- [ ] Debug disabled deletes temp files.
- [ ] Logs do not contain transcript text.
- [ ] Missing model error is readable.

## 10. Known acceptable failures in v0

- Perfect punctuation is not required.
- Full email formatting is not required.
- Selected text replacement is not required.
- Context-aware rewriting is not required.
- Clipboard restoration is not required.
- Real-time streaming is not required.
