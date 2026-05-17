# Risks and Open Questions

## 1. Technical risks

### Risk 1 — Global shortcut reliability

macOS permissions can make global shortcuts inconsistent across machines.

Mitigation:

- Provide menu fallback.
- Start with F6 toggle.
- Add clearer permission diagnostics.
- Later use a more robust shortcut registration mechanism.

### Risk 2 — Paste event reliability

Some apps may reject or delay simulated paste.

Mitigation:

- Always copy final output before paste.
- Leave output on clipboard by default.
- Add app-specific tests.
- Later use Accessibility API direct insertion for supported apps.

### Risk 3 — Whisper latency

Launching `whisper-cli` for every dictation may be slow.

Mitigation:

- Start with small models.
- Enable Metal/Core ML acceleration.
- Later run a persistent local service.
- Later embed runtime directly.

### Risk 4 — Audio format mismatch

Whisper runtime may behave poorly if audio is not the expected format.

Mitigation:

- Standardize to 16 kHz mono WAV.
- Validate output file.
- Add conversion step if needed.

### Risk 5 — Cleanup changes meaning

Even rule-based cleanup can remove words incorrectly.

Mitigation:

- Keep cleanup conservative.
- Add raw transcript mode.
- Write tests around filler removal.
- Avoid LLM cleanup in v0.

### Risk 6 — Sensitive data retention

Temporary audio/transcripts could persist after errors.

Mitigation:

- Delete on success.
- Clean stale temp files on launch.
- Debug retention must be explicit.
- Do not log transcript content.

### Risk 7 — App bundle complexity

Swift Package executable is easier than a polished `.app`, but not as user-friendly.

Mitigation:

- Prototype with `swift run` first.
- Package later after core loop works.

## 2. Product risks

### Risk 1 — Native dictation may be “good enough”

If the app is not meaningfully faster/better, it will not be used.

Mitigation:

- Optimize around personal vocabulary and local privacy.
- Use in real writing contexts, not demo phrases.

### Risk 2 — Overbuilding context too early

Trying to match Wispr-style context awareness can stall the project.

Mitigation:

- v0: no screen reading.
- v1: active app only.
- v2: selected text/context after core loop is stable.

### Risk 3 — Too many modes

Email/chat/code/note modes can create product complexity.

Mitigation:

- Start with raw vs clean only.
- Add app styles only after usage patterns are clear.

## 3. Open questions

1. Should the first trigger be toggle-to-record or hold-to-talk?
   - Recommendation: toggle first, hold-to-talk later.

2. Should clipboard be restored automatically?
   - Recommendation: no by default; restore can race with slow apps.

3. Should the app store dictation history?
   - Recommendation: no for v0.

4. Should local LLM cleanup be included in v0?
   - Recommendation: no. Rule-based first.

5. Which model should be default?
   - Recommendation: `base.en` for first test, `small.en` for daily use if latency is acceptable.

6. Should app block Terminal pastes?
   - Recommendation: add warning/block later. For v0, document risk.

7. Should the app read selected text?
   - Recommendation: not in v0.

8. Should the app ship with whisper.cpp bundled?
   - Recommendation: not for v0. User supplies local binary and model path.

9. Should the app use SwiftUI or pure AppKit?
   - Recommendation: AppKit menubar first; SwiftUI settings window later.

10. Should vocabulary be in config or separate file?
    - Recommendation: config for v0, separate `vocabulary.json` later.

## 4. Decision log

| Decision | Current choice | Why |
|---|---|---|
| Platform | macOS only | User wants quick Mac app |
| Language | Swift | Best native access to AVFoundation/AppKit |
| Runtime | whisper.cpp CLI | Fastest local integration |
| Trigger | F6 toggle | Simpler than hold-to-talk |
| Paste | Clipboard + Cmd+V | Broadest compatibility |
| Cleanup | Rule-based | Local, safe, deterministic |
| Context | Active app name only | Avoids privacy/complexity early |
| Retention | Delete by default | Privacy-first |
| Logs | Metadata only | Avoid transcript leakage |

## 5. Kill criteria for v0 approach

Switch architecture if:

- CLI startup makes every dictation feel unusably slow even with small models.
- Paste fails in most target apps.
- Swift menubar app becomes too painful to package/run.
- Hotkey cannot be made reliable enough.

Fallback options:

- Python prototype for faster iteration.
- Tauri wrapper if UI becomes more important.
- Local HTTP transcription daemon to reduce CLI startup overhead.
- Apple Speech fallback for initial prototype only.
