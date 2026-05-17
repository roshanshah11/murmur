# Phase 13 Verification Scenario Matrix — Run Results

**Run date:** 2026-05-17 (19:16 EDT)
**Bundle under test:** `/Users/roshanshah1/Downloads/flow_local_mac_prd/app/build/Murmur.app`
**Murmur version:** `Murmur v0` (reported by `--version`)
**Active config** (`~/Library/Application Support/Murmur/config.json`):

- `activeProfile`: `casual`
- `language`: `en`
- `model`: `ggml-base.en.bin`
- `historyEnabled`: `false`
- `rawTranscriptMode`: `false`
- `vocabulary.entries`: 6 brand-name entries (none match scenario fixtures)

## Pre-flight infrastructure fixes

Before any scenario could run, two pre-existing infra defects had to be patched. Both are in shell/JSON (no Swift changes per the constraint):

1. **Scenario JSON `input_wav` / `vocabulary_file` paths**. The 8 scenario JSONs referenced fixtures via `../fixtures/...` but the adapter resolves relative to `SCENARIO_DIR` (= `app/Scripts/scenarios/`), so `../fixtures/...` pointed at the nonexistent `app/Scripts/fixtures/`. The real fixtures live at `app/Scripts/scenarios/fixtures/`. Rewrote each path to `fixtures/...`. (07's `dmg_path` was left as-is — best-effort scenario, skip expected anyway.)
2. **`scenario_runner.sh` `set -e` swallowed JSON emission on adapter failure**. `set -euo pipefail` was active when the adapter ran; a non-zero adapter exit terminated the runner before the `jq -n ... '{id, status, ...}'` JSON line ever printed. Wrapped the dispatch in `set +e` / `set -e` so failed runs still emit the result line.

## Critical caveat — CLI flag gap

`app/Sources/Murmur/CLI.swift::CLI.parse` accepts only `--help`, `--version`, `--record-once`, `--transcribe-only <wav>`. The Phase 13 `cli_transcribe` adapter passes `--profile`, `--language`, `--model`, `--vocabulary` — all of which are **silently ignored**. Every cli_transcribe scenario therefore ran under whatever the live `config.json` dictated (profile=`casual`, language=`en`, model=`ggml-base.en`, vocab=brand-only). Any scenario whose assertions require a *different* profile, vocab file, or model (01, 02, 04) cannot pass via the headless CLI today — the engine never sees the scenario's intended config. This is a load-bearing finding for Phase 13's gate decision.

## Summary

| ID | Hard gate? | Status | Failure reason |
|----|------------|--------|----------------|
| 01_devraj_code_cursor | YES | FAIL | Vocab substitution `auth underscore E X P underscore missing → AUTH_EXP_MISSING` never applied (transcript: `orth_exp_missing`). CLI ignores `--vocabulary`; active profile is `casual` not `code`. |
| 02_priya_word_legal | YES | FAIL | Base.en model produced `12b6`, `Twombli`, `race juda cada`, `impari de licto`. No vocab substitution; active profile is `casual` not `formal`. |
| 03_jordan_airpods | no (best-effort) | FAIL | Transcript contains `I/O bound` but assertion is literal `IO bound`. Fixture/assertion mismatch — the slash in `I/O` defeats the `grep -F` substring check. |
| 04_tomas_spanish | YES | FAIL | English-only model `ggml-base.en` transcribed Spanish audio as English garble (`The oil and salmon and oil…`). CLI ignores `--model` and `--language`. |
| 05_eunji_offline | YES | PASS | Raw profile, no whisper artifacts present in transcript. |
| 06_yusuf_permission_loss | no (best-effort) | FAIL | `tccutil` reset failed without sudo / TCC entitlement. Interactive prereq not met → adapter should arguably skip-77 here, but reports fail. |
| 07_tabitha_first_launch | no (best-effort) | SKIP | No signed DMG at `app/build/Murmur-1.0.0.dmg` — `package_dmg.sh` not run. |
| 08_sam_history_search | YES | PASS | Transcript contains `Q3` and `hiring`; forbidden forms absent. Note: history-DB assertions (`history_assertions` block) are not exercised by `cli_transcribe.sh` — pure transcript check only. |

**Hard-gate tally:** 2 pass (05, 08), 3 fail (01, 02, 04), 0 skip → **RED**

## Verdict

**RED — blocks v1.0.0 tag.**

Three of five hard-gate scenarios fail. The proximate cause for all three (01, 02, 04) is the same: `Murmur --transcribe-only` ignores the `--profile`, `--language`, `--model`, and `--vocabulary` flags the Phase 13 adapter passes. Until the CLI surface plumbs those flags through to `WhisperRunner`/`TextCleaner`, the scenario matrix cannot reach a green state regardless of fixture quality.

## Per-scenario detail

### 01_devraj_code_cursor (HARD GATE — FAIL)

Runner JSON:
```json
{"id":"01_devraj_code_cursor","type":"cli_transcribe","summary":"Code profile preserves UPPER_SNAKE constants and numeric '401'","status":"fail","exit_code":1,"duration_seconds":1}
```

Transcript:
> Refactor the orth middleweight or short circuit when the JWT EXP claim is null. Return 401 with code orth_exp_missing, and add a unit test covering the null path.

Assertion misses: `AUTH_EXP_MISSING` substring + regex.

**fail_hint:** *"code-profile regression OR vocabulary case-sensitivity broke. Inspect CleanupService.swift::CodeProfile.apply()."*

**Diagnostic:** The deeper culprit is `CLI.swift::CLI.parse` — `--profile code` and `--vocabulary fixtures/01-devraj-vocab.json` are dropped on the floor. Without those, `CodeProfile.apply()` never runs and the spoken `"auth underscore E X P underscore missing"` is transcribed as `orth_exp_missing` and stays that way. Fix in `app/Sources/Murmur/CLI.swift`.

### 02_priya_word_legal (HARD GATE — FAIL)

Runner JSON:
```json
{"id":"02_priya_word_legal","type":"cli_transcribe","summary":"Formal profile keeps Rule 12(b)(6) literal punctuation + Latin terms","status":"fail","exit_code":1,"duration_seconds":1}
```

Transcript:
> The plaintiff's claim fails as a matter of law under Rule 12b6 because the complaint does not meet the Iqbal Twombli pleading standard, and the doctrine of impari de licto and race juda cada both barre leave.

Assertion misses: `12(b)(6)`, `res judicata`, `in pari delicto`, `Twombly`; regex `12\(b\)\(6\)` no match.

**fail_hint:** *"vocabulary substitution rules don't support literal parens, OR Formal profile rewrote citations. Inspect VocabularyEngine + FormalProfile."*

**Diagnostic:** Same CLI flag gap (`--profile formal`, `--vocabulary` ignored). Even if those were honored, the base.en model heard `Twombli` / `juda cada` — a multi-step vocab pipeline (or a stronger model) would be required.

### 03_jordan_airpods (best-effort — FAIL)

Runner JSON:
```json
{"id":"03_jordan_airpods","type":"cli_transcribe","summary":"Recording resolves the live input device, not the launch-time one","status":"fail","exit_code":1,"duration_seconds":1}
```

Transcript:
> Idea for OS final project, build a tiny scheduler that uses CFS but adds a fairness boost for I/O bound threads.

Assertion miss: `IO bound` (the literal substring). The audio said "I/O bound" and whisper transcribed `I/O bound`.

**fail_hint:** *"AVAudioEngine cached the built-in mic at app launch and ignored AirPods. Inspect AudioInputResolver — must re-query default input at recordStart()."*

**Diagnostic:** This is a scenario-spec defect, not a Murmur defect — the `expect_contains` substring should be `I/O bound` (or use a regex with optional slash). Best-effort, can be deferred.

### 04_tomas_spanish (HARD GATE — FAIL)

Runner JSON:
```json
{"id":"04_tomas_spanish","type":"cli_transcribe","summary":"Spanish locale forces non-.en model; accents and '+' brand survive","status":"fail","exit_code":1,"duration_seconds":1}
```

Transcript:
> The oil and salmon and oil can be used in the United States.

Assertion misses: all four Spanish substrings.

**fail_hint:** *"(a) wrong model auto-picked — .en model on Spanish input. Inspect ModelResolver::languageGuard. (b) cleanup stripped '+'. Inspect VocabularySanitizer punctuation allowlist."*

**Diagnostic:** The scenario asked for `ggml-base` (multilingual) + `language es` + the brand vocab. The CLI ignored every one of those and ran the English-only `ggml-base.en` model against Spanish audio, hallucinating English. The cure is plumbing through `--model`, `--language`, `--vocabulary` in `CLI.swift` and adding a `language → model` guard in `WhisperRunner` (or `ModelResolver` if that file exists).

### 05_eunji_offline (HARD GATE — PASS)

Runner JSON:
```json
{"id":"05_eunji_offline","type":"cli_transcribe","summary":"Full record→transcribe loop leaks zero network egress; whisper artifacts stripped","status":"pass","exit_code":0,"duration_seconds":1}
```

`pass: 1s wall, 283 bytes transcribed`. Transcript contains `contract was signed` and `audit`; none of `[Music]`/`[Applause]`/`[BLANK_AUDIO]`/`(music playing)` appear. Note: the `network_egress_assertion` block is metadata only — the `cli_transcribe` adapter does not actually probe `lsof`. A true egress assertion would need a wrapper that spawns Murmur, captures PID, polls `lsof -nP -iTCP -sTCP:ESTABLISHED -p $PID` during the run, and fails on any line.

### 06_yusuf_permission_loss (best-effort — FAIL)

Runner JSON:
```json
{"id":"06_yusuf_permission_loss","type":"permissions_probe","summary":"Accessibility silently revoked; Murmur must detect within 200ms and surface a banner","status":"fail","exit_code":1,"duration_seconds":0}
```

stderr: `fail: Accessibility still appears granted after reset — tccutil didn't take?`

**Diagnostic:** `tccutil reset Accessibility com.murmur.app` requires either sudo or the TCC private entitlement and can silently no-op without them. Interactive prereq — should arguably be skip-77 not fail. Adapter-level cleanup recommended in `permissions_probe.sh`.

### 07_tabitha_first_launch (best-effort — SKIP)

Runner JSON:
```json
{"id":"07_tabitha_first_launch","type":"installer_flow","summary":"Fresh DMG install on a clean account reaches a working menubar agent","status":"skip","exit_code":77,"duration_seconds":0}
```

stderr: `skip: signed DMG not present at .../app/build/Murmur-1.0.0.dmg (build it with app/Scripts/package_dmg.sh first)`. Expected — `package_dmg.sh` has not been run.

### 08_sam_history_search (HARD GATE — PASS)

Runner JSON:
```json
{"id":"08_sam_history_search","type":"cli_transcribe","summary":"History DB stores raw+cleaned+timestamp+bundle id and is FTS-indexed","status":"pass","exit_code":0,"duration_seconds":1}
```

`pass: 1s wall, 286 bytes transcribed`. Transcript contains `Q3` and `hiring`; forbidden forms (`Q three`, `quarter three`) absent.

**Caveat:** The `history_assertions` block (FTS search latency, row schema, copy-button payload) is **not exercised** by `cli_transcribe.sh` — the scenario `notes` field flagged this and punted the implementation decision to the Phase 13 task owner. Treat this PASS as covering only the transcript-side gate, not the history-DB-side gate.

## Most-actionable next step

Plumb `--profile`, `--language`, `--model`, and `--vocabulary` flags through `CLI.swift::CLI.parse` and into `runTranscribeOnly`, then rerun 01/02/04. Without that single change, no amount of fixture/vocab tuning can move scenarios 01, 02, or 04 to green and the v1.0.0 tag stays blocked.
