# Local-First Transcription Strategy

## 1. Recommended v0 approach

Use `whisper.cpp` as a local command-line sidecar.

Why this is the right first build:

- It avoids cloud APIs.
- It runs locally on Apple Silicon and Intel Macs.
- It can be tested independently from the app.
- It avoids embedding C/C++ into Swift at the start.
- It allows fast iteration on model choice.

## 2. Runtime options

### Option A — `whisper.cpp` CLI sidecar

Best for v0.

Pipeline:

```text
record WAV
→ run whisper-cli process
→ read output txt
→ cleanup
→ paste
```

Pros:

- Simple integration
- Easy debugging
- Local-only
- Model/runtime can be updated without rebuilding app

Cons:

- Process startup overhead
- No true streaming
- File-based pipeline

### Option B — Embedded `whisper.cpp` library

Best for later.

Pros:

- Lower latency
- More control
- Cleaner shipping story

Cons:

- C/C++ bridging complexity
- Build and linking complexity
- Harder first implementation

### Option C — Local server

Run a local transcription daemon and call it over localhost.

Pros:

- Avoid process startup overhead
- Easier language boundary
- Can support streaming later

Cons:

- Extra process lifecycle
- Port management
- More moving parts

### Option D — Apple Speech framework

Possible fallback, but not ideal as the primary local-first implementation because availability and on-device behavior can vary by OS/device/language.

## 3. Model choice

Recommended models for MVP:

| Model | Use case | Tradeoff |
|---|---|---|
| `base.en` | Fast MVP, short dictation | Lower accuracy |
| `small.en` | Better default | Slightly slower |
| `medium.en` | Better accuracy for names/technical terms | Slower |
| `large-v3-turbo` if supported locally | Stronger accuracy/speed balance | Larger setup |

Start with `base.en` or `small.en` until the app flow is reliable. Upgrade accuracy after paste/reliability works.

## 4. Audio format

Target input format:

```text
WAV
16 kHz
mono
16-bit PCM
```

Reasons:

- Standard ASR input
- Small files
- Fast local processing
- Avoids conversion surprises

## 5. CLI invocation pattern

Example command:

```bash
/path/to/whisper-cli \
  -m /path/to/models/ggml-base.en.bin \
  -f /tmp/flow-lite/input.wav \
  -l en \
  -nt \
  -otxt \
  -of /tmp/flow-lite/output
```

Expected output:

```text
/tmp/flow-lite/output.txt
```

Implementation should check:

- binary exists
- binary is executable
- model exists
- input audio exists
- output file was created
- transcript is non-empty

## 6. Latency budget

The user experience depends on stop-to-paste latency, not transcription accuracy alone.

Target:

```text
5-second dictation: paste within ~1–3 seconds on a good Mac
15-second dictation: paste within ~2–6 seconds depending on model
60-second dictation: acceptable if progress state is clear
```

Optimization order:

1. Smaller model.
2. Metal/Core ML acceleration.
3. Long-lived local service.
4. Streaming partials.
5. Embedded runtime.

Do not optimize before the end-to-end flow works.

## 7. Cleanup strategy

v0 cleanup should be local and deterministic.

Allowed cleanup:

- trim leading/trailing whitespace
- collapse repeated spaces
- remove standalone filler words
- apply user-defined vocabulary replacements
- capitalize first character
- add terminal punctuation if missing

Forbidden cleanup:

- adding facts
- changing numbers
- changing named entities unless dictionary explicitly says so
- turning rough notes into a different argument
- sending transcript to cloud

## 8. Optional local LLM cleanup

v2 can support optional local LLM cleanup through a local-only endpoint.

Example local prompt:

```text
You are a local dictation cleanup engine.
Rewrite the transcript into clean text.
Preserve meaning exactly.
Do not add facts.
Do not remove important details.
Return only the final cleaned text.
```

Requirements before enabling:

- timeout control
- fallback to raw/rule-based output
- no network calls
- visible mode indicator
- tests for meaning preservation

## 9. Custom vocabulary

Format:

```json
{
  "cofounders capital": "Cofounders Capital",
  "caju dot ai": "Caju.ai",
  "element four fifty one": "Element451",
  "kenan flagler": "Kenan-Flagler",
  "pmt": "PMT"
}
```

Apply after filler cleanup and before final capitalization.

Rules:

- Match case-insensitively.
- Replace whole phrases.
- Do not replace inside longer words.
- Preserve replacement exactly.

## 10. Debugging transcription

Add a smoke test:

```bash
swift run FlowLite --transcribe-only ./sample.wav
```

Or direct runtime test:

```bash
/path/to/whisper-cli -m /path/to/model.bin -f ./sample.wav -l en -nt
```

Debug artifacts:

- input WAV
- raw transcript
- cleaned transcript
- stderr/stdout from whisper process

Default should not retain these unless debug mode is enabled.
