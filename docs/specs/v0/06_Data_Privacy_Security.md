# Data, Privacy, and Security Spec

## 1. Privacy principle

Flow Lite should be private by default and local-first by architecture. The user should not need to trust a server, vendor, analytics platform, or external logging system to use basic dictation.

## 2. Data classes

| Data | Sensitivity | Default retention |
|---|---:|---|
| Raw audio | High | Delete after transcription |
| Raw transcript | High | In memory only; temp file deleted |
| Cleaned output | High | Clipboard only after paste |
| Active app name | Low-medium | Log metadata only if logging enabled |
| Config | Medium | Persist locally |
| Custom vocabulary | Medium | Persist locally |
| Logs | Medium | Persist locally, no content by default |

## 3. v0 retention policy

Default:

- Delete audio temp file after successful transcription.
- Delete transcript output file after successful cleanup/paste.
- Do not store dictation history.
- Do not log transcript text.
- Do not perform network requests.

Debug mode:

- Explicitly retain audio and transcript files.
- Clearly label debug artifacts.
- Store under `~/.flow-lite/debug/` or temp folder.

## 4. Network policy

v0 must make zero network calls.

Implementation guidance:

- Do not include analytics SDKs.
- Do not auto-update models remotely.
- Do not call cloud LLMs.
- Do not send crash reports.
- Avoid package code that phones home.

Optional future cloud mode must be explicit and visibly marked.

## 5. Permissions

### Microphone

Needed to record dictation audio.

Risk:

- Captures sensitive speech.

Mitigation:

- Record only during explicit active dictation state.
- Show visible recording state.
- Stop on explicit shortcut/menu action.
- Delete files by default.

### Accessibility / Input Monitoring

Needed for reliable global shortcut and simulated paste.

Risk:

- Powerful permission; can observe or control UI events.

Mitigation:

- v0 should not read screen content.
- Use permission only for shortcut/paste.
- Document why permission is needed.
- Do not collect Accessibility-tree text by default.

### Clipboard

Needed to paste output.

Risk:

- Clipboard may contain sensitive user data.

Mitigation:

- Avoid reading clipboard unless restoration is enabled.
- If reading clipboard for restoration, only store in memory briefly.
- Do not log clipboard content.
- Leave output on clipboard by default rather than racing restoration.

## 6. Threat model

### Threat: local temp files expose sensitive audio

Mitigation:

- Store in temp directory.
- Delete after successful operation.
- Use predictable cleanup on app launch to remove stale temp files.

### Threat: transcript gets logged

Mitigation:

- Logging layer should mark transcript content as sensitive.
- Do not include transcript in default logs.
- Debug logs require explicit opt-in.

### Threat: accidental paste into wrong app

Mitigation:

- v0 cannot fully prevent this.
- User controls cursor location.
- Add frontmost app logging.
- Future: optional confirmation for Terminal, password managers, banking sites, or secure fields.

### Threat: simulated paste into Terminal executes command

Mitigation:

- Future setting: block paste into Terminal unless confirmed.
- v0 note: user should avoid dictating shell commands into Terminal.

### Threat: malicious local config path

Mitigation:

- Validate binary path exists and is executable.
- Do not run arbitrary command strings; only run configured binary with controlled argument list.
- Do not pass shell-interpreted command.
- Use `Process` with arguments array, not `/bin/sh -c`.

### Threat: local model/binary tampering

Mitigation:

- Document trusted installation path.
- Future: checksum known model files.
- Future: code signing for bundled runtime.

## 7. Security implementation rules

1. Do not run shell strings.
2. Do not log transcript content by default.
3. Do not persist audio by default.
4. Do not use cloud APIs in v0.
5. Do not read screen context in v0.
6. Always copy transcript to clipboard before paste attempt.
7. Never auto-send messages.
8. Avoid hidden background recording.
9. Show visible recording state.
10. Stop recording on app quit.

## 8. Local file locations

Recommended:

```text
~/.flow-lite/config.json
~/.flow-lite/logs/flow-lite.log
~/.flow-lite/vocabulary.json
~/Library/Caches/FlowLite/temp/
~/Library/Caches/FlowLite/debug/
```

## 9. Future privacy modes

### Strict local mode

- no network
- rule-based cleanup only
- no history
- no context reading

### Local enhanced mode

- local LLM cleanup
- optional local history
- optional context through Accessibility API

### Cloud opt-in mode

Not recommended for personal v0. If ever built:

- explicit provider
- explicit retention warning
- per-dictation indicator
- separate API key
- no silent fallback to cloud

## 10. Privacy acceptance checklist

Before using daily:

- [ ] Works with network disabled.
- [ ] Audio files deleted after successful dictation.
- [ ] Transcript files deleted after successful dictation.
- [ ] Logs do not include transcript text.
- [ ] App displays recording state.
- [ ] Config cannot execute arbitrary shell code.
- [ ] Output remains accessible if paste fails.
