# Plan: Add NVIDIA Parakeet (FluidAudio) as default transcription engine

**Branch:** `feature/parakeet-engine` (in-place; carries the pre-existing Settings
window-sizing fix as its first commit).

**Decision (settled, do not re-litigate):** Add Parakeet `parakeet-tdt-0.6b-v3`
via the **FluidAudio** SwiftPM SDK (Core ML / Apple Neural Engine) as the new
default engine; keep whisper.cpp as a selectable fallback (covers 99 languages
vs Parakeet's ~25). No Python, no out-of-process runtime — stay a single Swift
executable.

## Settled product decisions (from the user)

- **Minimum macOS rises 13 → 14.** FluidAudio requires macOS 14.0; SwiftPM
  cannot link a macOS-14 package into a macOS-13 target. `Package.swift`
  platform → `.macOS(.v14)`. README / docs updated to macOS 14+.
- **Default engine is arch-aware:** Parakeet on Apple Silicon, whisper.cpp on
  Intel (Parakeet falls back to slow CPU/GPU Core ML off the ANE). User can
  override either way; the choice persists.

## Environment (verified)

- This dev box: **arm64 / Apple Silicon**, macOS 26.5, Swift 6.3.2, Xcode + gh
  present. Parakeet runs on the ANE here → full end-to-end verification feasible.
- FluidAudio latest release = **v0.15.1** → pin `.exact("0.15.1")`.

## Confirmed FluidAudio API (Context7 + GitHub; spike will finalize)

```swift
let models = try await AsrModels.downloadAndLoad(version: .v3)   // multilingual
let asr = AsrManager(config: .default)
try await asr.loadModels(models)                                 // NOT initialize()
var decoderState = TdtDecoderState()
let result = try await asr.transcribe(samples, decoderState: &decoderState)   // [Float] 16k mono
print(result.text, result.confidence, result.rtfx)
// Convert WAV → samples:  let samples = try AudioConverter().resampleAudioFile(wavURL)
// File overload exists:   asr.transcribe(url, decoderState:&s, language: .french)
// Model from HF:          FluidInference/parakeet-tdt-0.6b-v3-coreml (~2.3 GB), auto-cached
```

The spike (Task 2) is the source of truth — finalize Parakeet-dependent task
prompts only after it confirms exact names, cache path, and **offline** transcribe.

### T2 spike findings (CONFIRMED on M3 Pro, macOS 26.5)

- **API (exact, v0.15.1):**
  - `try await AsrModels.downloadAndLoad(version: .v3, progressHandler: { (p: DownloadUtils.DownloadProgress) in p.fractionCompleted /* Double 0..1 */, p.phase })` → `AsrModels`. Handler "called on an unspecified queue" → hop to MainActor for UI.
  - `let asr = AsrManager(config: .default)` (it's a `public actor`); `try await asr.loadModels(models)`.
  - `var state = try TdtDecoderState()` — **the initializer throws**.
  - `try await asr.transcribe(url, decoderState: &state, language: Language(rawValue: code))` → `ASRResult` (`.text`, `.confidence`, `.duration`, `.processingTime`, `.rtfx`). The **file-URL overload** resamples internally and auto-switches to disk-backed for long audio → ParakeetEngine passes the WAV directly; no manual `AudioConverter` needed.
  - Language: shared `public enum Language: String` (`.english="en"`, 25 EU langs). `Language(rawValue: code)` maps directly; `""`/unknown → `nil`.
  - Installed check: `AsrModels.modelsExist(at:)` / `modelsExist(at:version:)`.
- **Result:** input `say "the quick brown fox jumps over the lazy dog"` → `The quick brown fox jumps over the lazy dog.` conf 0.99, **rtfx 26×**, Encoder on `cpuAndNeuralEngine` (ANE).
- **Cache:** `~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3` — **~470 MB** for v3 at default `int8` encoder precision (NOT 2.3 GB; that was fp32). Comparable to whisper-small (466 MB). FluidAudio-managed, outside Murmur's `AppPaths`.
- **Offline:** cached load logs "Found … locally, no download needed"; inference is pure local Core ML. FluidAudio also exposes an `enforceOffline` mode that blocks re-download. → "no network at inference" holds once cached.
- **BRIDGE DECISION:** the semaphore-blocking-a-DispatchQueue-worker-while-awaiting-the-actor pattern returned identical text with **no deadlock**. → **T3 keeps `AppState.runPipeline` synchronous** and calls the engine through an `AsyncBridge.runBlocking` helper. (Dispatch-queue worker threads are not Swift-concurrency cooperative threads, so blocking them doesn't starve the pool.)
- **For T9 (advisor #3):** Parakeet output is **Truecased + punctuated**, unlike whisper's `-nt` lowercase style. TextCleaner Raw/Casual/Formal/Code profiles + Vocabulary must be verified on a Parakeet transcript.

## Architecture of the change

`AppState.runPipeline` (background `DispatchQueue`, currently **synchronous**)
calls `try whisper.transcribe(audioURL:)`. We introduce:

```swift
protocol TranscriptionEngine {
    func transcribe(wavURL: URL, language: String?) async throws -> String
    func prepare() async throws            // preload models / validate; default no-op
}
extension TranscriptionEngine { func prepare() async throws {} }
```

Two conformers:
- **`WhisperCppEngine`** — wraps existing `WhisperRunner` subprocess logic
  verbatim (timeout scaling, async pipe draining, thread auto-tune). Out-of-process.
- **`ParakeetEngine`** — `actor`, FluidAudio-backed, loads `AsrManager` **once**
  and reuses it. In-process Core ML / ANE.

`AppState` stores `let engine: any TranscriptionEngine` (built by a factory from
`config.transcriptionEngine`). The downstream stages (TextCleaner, Vocabulary,
PasteboardInserter, NotchIndicator, history) are **unchanged** — they keep
operating on the returned `String`.

**Async→sync bridge:** the spike (Task 2) decides between (a) a contained
`AsyncBridge.runBlocking` semaphore helper called from the existing background
queue, or (b) converting `runPipeline` to `async` via `Task`. Per advisor:
"keep StateMachine unchanged" governs the String-consumers, not the queue
mechanics — option (b) is allowed. Pick whichever the spike proves
deadlock-free from a real `DispatchQueue`.

## Wiring touch-points (verified file/line)

- `app/Sources/Murmur/main.swift:26` — constructs `WhisperRunner(config:)`,
  injects into `AppState`; `try? whisper.validateSetup()`; menubar
  "Test Whisper Setup" → `appState.whisper.validateSetup()`.
- `app/Sources/Murmur/CLI.swift:179` — `runTranscribeOnly` constructs
  `WhisperRunner`, sync `transcribe`. Returns `Int32`.
- `app/Sources/Murmur/AppState.swift:45,92,188` — stored `whisper`, init param,
  `try whisper.transcribe(audioURL:)` call site in `runPipeline`.
- `app/Sources/Murmur/Config.swift` — hand-rolled `Codable`: explicit
  `CodingKeys`, `init(from:)` with `decodeIfPresent ?? default`, `encode`,
  `defaultConfig()`. New field follows this exact pattern.
- `app/Sources/Murmur/Transcription/ModelManager.swift` + `ModelManifest.swift`
  — GGML download/verify/select with `@Published downloads[name]` progress.
- `app/Sources/Murmur/UI/Settings/ModelsTab.swift` — model + language picker;
  posts `.murmurModelDownloadProgress` / `.murmurModelDownloadFinished`.
- Notch already has `MurmurState.downloadingModel(progress:)`.

---

## Tasks

### T1 — Package.swift: bump to macOS 14, add FluidAudio (foundational)
- `platforms: [.macOS(.v14)]`.
- Add dependency `.package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.1")`
  and product `.product(name: "FluidAudio", package: "FluidAudio")` to the
  `Murmur` target.
- `swift build` must resolve + compile (no code using FluidAudio yet — just link).
- Verify the tag with `gh release list -R FluidInference/FluidAudio` before pinning.
- **Done when:** clean build with the dependency resolved.

### T2 — FluidAudio spike (throwaway; gates all Parakeet work)
- ~20-line standalone (a temporary `spike/` executable target or a gated unit
  test) that does: `downloadAndLoad(.v3)` → `AsrManager` → load → transcribe a
  small sample 16k mono WAV → print `.text`.
- Confirm: exact type/method names; result type fields; model cache
  location + size; **transcribe works offline after download** (kill network or
  re-run with no download) → satisfies "no network at inference."
- Exercise the **semaphore bridge from a real `DispatchQueue.async`** block (not
  a top-level `Task {}`). If it hangs → mandate the `async runPipeline` route.
- **Done when:** a Parakeet transcript prints, offline re-run works, and the
  bridge decision is recorded in this plan. Delete the spike target afterward.

### T3 — `TranscriptionEngine` protocol + `WhisperCppEngine` refactor (zero behavior change)
- Define the protocol (+ default `prepare()`).
- Move `WhisperRunner`'s subprocess logic into `WhisperCppEngine: TranscriptionEngine`
  (async `transcribe` wrapping the existing synchronous work; `prepare()` =
  `validateSetup()`). Keep timeout scaling, pipe draining, thread auto-tune
  **inside** the engine. May keep `WhisperRunner` as the internal impl that
  `WhisperCppEngine` delegates to, to minimize churn and preserve tests.
- Add `AsyncBridge.runBlocking` (or the async-`runPipeline` variant per T2).
- Add `TranscriptionEngineFactory.make(config:) -> any TranscriptionEngine`
  (whisper-only for now).
- Rewire `AppState` (`engine` instead of `whisper`), `main.swift`, `CLI.swift`
  through the factory + bridge. Update "Test … Setup" menu to call active
  engine's `prepare()`.
- **Done when:** `swift build` + `swift test` green; behavior identical for whisper.

### T4 — `Config.transcriptionEngine` (arch-aware default + migration)
- Add `enum TranscriptionEngineKind: String, Codable { case parakeet, whisperCpp }`.
- Add `var transcriptionEngine: TranscriptionEngineKind` to `Config` following
  the exact hand-rolled-Codable pattern: `CodingKeys` entry, `init(from:)`
  `decodeIfPresent ?? d.transcriptionEngine`, `encode`, constructor param,
  `defaultConfig()`.
- Default value = arch-aware: Apple Silicon → `.parakeet`, Intel → `.whisperCpp`
  (runtime check via `sysctlbyname("hw.optional.arm64", …)`).
- Old configs lacking the key decode to the arch default (test it).
- **Done when:** round-trip + legacy-decode tests pass.

### T5 — `ParakeetEngine` (FluidAudio actor) — finalize prompt only after T2
- `actor ParakeetEngine: TranscriptionEngine`. Lazy `ensureLoaded()` →
  `AsrModels.downloadAndLoad(.v3)` + `AsrManager.loadModels` **once**, cached.
- `transcribe(wavURL:language:)`: `AudioConverter().resampleAudioFile(wavURL)` →
  `transcribe(samples, decoderState:&)` → `.text`. (MVP keeps the WAV; **no**
  Float32-capture rewrite — that would break the mandated `wavURL` protocol.)
- `prepare()` = `ensureLoaded()` (used for launch preload).
- Map `config.language` (whisper-style string / ""=auto) → FluidAudio
  `Language?` (nil when unknown/auto). Unit-test the mapping.
- All FluidAudio specifics stay inside this file.
- Factory returns `ParakeetEngine` when `config.transcriptionEngine == .parakeet`.
- **Done when:** factory wired; unit tests for language mapping pass; builds.

### T6 — Settings: engine chooser in ModelsTab
- Segmented control (Parakeet ▸ Apple Neural Engine / Whisper.cpp) at top of the
  Models tab; bound to `config.transcriptionEngine` (persist via inline
  load→mutate→save, matching ModelsTab's existing pattern; default reflects config).
- When **Parakeet** selected: show the Parakeet model row (state from T7).
  When **Whisper** selected: show the existing GGML list. Language picker note:
  Parakeet = 25 European langs, Whisper = 99.
- **Done when:** toggling persists across launch; correct model UI shows per engine.

### T7 — Parakeet model download UX — finalize prompt only after T2
- `ParakeetModelManager` (thin `@MainActor ObservableObject`) exposing
  installed-state + a `download()` that surfaces progress, mirroring the GGML
  pattern. Source progress from FluidAudio's real download API **if it exposes a
  callback/stream** (investigate in T2); else show an indeterminate
  "Downloading Parakeet model…" state. Reuse the `.murmurModelDownloadProgress`
  → notch bridge.
- **First-run graceful fallback (advisor):** if Parakeet is default but the
  ~470 MB model isn't downloaded yet, do NOT block the first dictation — kick off a background download (progress in notch) and, until ready,
  fall back to an installed whisper model if one exists; otherwise show a clear
  "model still downloading — N%" notice.
- Launch preload: `main.swift` fires `Task { try? await engine.prepare() }`.
- **Done when:** download shows progress; not-downloaded path is graceful; a
  ready Parakeet model transcribes.

### T8 — Docs
- Rewrite `docs/architecture.md`: remove the `Transcriber.swift` + `CWhisper`
  fiction; document `TranscriptionEngine` + `WhisperCppEngine` (subprocess) +
  `ParakeetEngine` (in-process Core ML/ANE); the subprocess-vs-in-process
  distinction; macOS 14 minimum; arch-aware default.
- Update README (min-OS 14), `docs/models.md` (Parakeet vs Whisper, sizes,
  language coverage), `docs/privacy.md` network surface (+ one-time FluidAudio
  HF model download; still no inference-time network).
- **Done when:** docs match the shipped code.

### T9 — Final verification (advisor-strengthened)
- `swift build` + full `swift test` green.
- Run a real transcription through **both** engines and inspect the
  **TextCleaner-cleaned** output (not just "text appeared"): Parakeet TDT emits
  different casing/punctuation than whisper, and the Raw/Casual/Formal/Code
  profiles were tuned on whisper — confirm profiles + vocabulary substitution
  still produce good text on a Parakeet transcript. Use `--transcribe-only`
  (add a `--engine parakeet|whisper` override) with a sample WAV for both.
- Confirm: transcript never written to any log; audio file deleted after the
  transcript reaches the clipboard (`deleteTempAudio`); only transient cache used.
- **Done when:** both engines produce good cleaned text and privacy invariants hold.

## Out of scope (explicit)
- Float32 direct-capture / skip-WAV (contradicts the mandated `wavURL` protocol;
  revisit only with an explicit protocol change).
- Live hot-swap of an in-flight engine (selection takes effect next dictation,
  matching existing model-selection behavior).
- Migrating other Settings tabs to `SettingsStore`.
