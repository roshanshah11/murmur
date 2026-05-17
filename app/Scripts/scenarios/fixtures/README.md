# Phase 13 Fixture WAVs

These fixtures are NOT in this draft. Generating them is a Phase 13 *task*, not
a planning artifact. This file documents what each fixture must contain and
how to produce it so the Phase 13 task owner can do it deterministically.

## Generation toolchain

- `say(1)` — built-in macOS TTS. Voices listed via `say -v ?`.
- `afconvert(1)` — convert the AIFF that `say` emits into 16 kHz / 16-bit /
  mono PCM WAV (whisper.cpp's preferred input).
- `sox(1)` (optional) — for the noisy / reverberant fixtures.

Canonical convert flags:

```sh
afconvert -f WAVE -d LEI16@16000 -c 1 in.aiff out.wav
```

## Per-fixture spec

### `01-devraj-code-comment.wav`
**Scenario**: 01_devraj_code_cursor.
**Spoken phrase** (one take, ~12s):
> "Refactor the auth middleware to short circuit when the J W T E X P claim is null,
>  return four oh one with code auth underscore E X P underscore missing,
>  and add a unit test covering the null path."

> Note: we speak the constant as letters because that's how a human dictating
> code says it. The vocabulary file (`01-devraj-vocab.json`) maps the spoken
> form to `AUTH_EXP_MISSING`. The test asserts the vocab rule fires.

```sh
say -v Daniel -o 01-devraj-code-comment.aiff \
  "Refactor the auth middleware to short circuit when the J W T E X P claim is null, return four oh one with code auth underscore E X P underscore missing, and add a unit test covering the null path."
afconvert -f WAVE -d LEI16@16000 -c 1 01-devraj-code-comment.aiff 01-devraj-code-comment.wav
```

Companion vocab file `01-devraj-vocab.json`:
```json
[
  { "spoken": "auth underscore E X P underscore missing", "replacement": "AUTH_EXP_MISSING" },
  { "spoken": "J W T",                                     "replacement": "JWT" },
  { "spoken": "four oh one",                                "replacement": "401" }
]
```

### `02-priya-motion.wav`
**Scenario**: 02_priya_word_legal.
**Spoken phrase** (~15s):
> "Plaintiff's claim fails as a matter of law under rule twelve b six because
>  the complaint does not meet the Iqbal Twombly pleading standard, and the
>  doctrine of in pari delicto and res judicata both bar relief."

Vocab file `02-priya-legal-vocab.json` must encode `"twelve b six" → "12(b)(6)"`,
`"in pari delicto" → "in pari delicto"`, etc. (Latin terms are vocab entries so
they round-trip exactly; the test exists specifically to verify literal-paren
support.)

```sh
say -v Samantha -o 02-priya-motion.aiff "<phrase above>"
afconvert -f WAVE -d LEI16@16000 -c 1 02-priya-motion.aiff 02-priya-motion.wav
```

### `03-jordan-airpods.wav`
**Scenario**: 03_jordan_airpods.
**Spoken phrase** (~10s):
> "Idea for OS final project: build a tiny scheduler that uses CFS but adds a
>  fairness boost for IO bound threads."

For the CLI mode this is functionally a plain transcription test. The *live*
device-selection portion of the scenario lives in the SwiftUI integration
tests (`AudioInputResolverTests.testRoutesToCurrentDefaultInput`) — the CLI
fixture just guards against whisper emitting `[BLANK_AUDIO]` for the actual
spoken content.

### `04-tomas-linkedin.wav`
**Scenario**: 04_tomas_spanish.
**Spoken phrase** (~12s, Spanish):
> "Hoy lanzamos la nueva campaña de retención con Talento+. Estoy muy orgulloso
>  del equipo y los OKR están en buen camino."

```sh
say -v Paulina -o 04-tomas-linkedin.aiff "<phrase above>"
afconvert -f WAVE -d LEI16@16000 -c 1 04-tomas-linkedin.aiff 04-tomas-linkedin.wav
```

Vocab file `04-tomas-brand-vocab.json`: maps `"Talento más"`/`"Talento plus"`
→ `"Talento+"`.

### `05-eunji-coffee-shop.wav`
**Scenario**: 05_eunji_offline.
**Spoken phrase** (~8s, quietly):
> "Source claims the contract was signed before the audit was completed."

Mix in 70 dB ambient (espresso + chatter). Public-domain coffee-shop background
loop from freesound.org, mixed at -10 dB to the voice using sox:

```sh
say -v Karen -o voice.aiff "<phrase above>"
afconvert -f WAVE -d LEI16@16000 -c 1 voice.aiff voice.wav
sox -m voice.wav coffee-shop-bg.wav 05-eunji-coffee-shop.wav
```

### `06-yusuf-permission-loss` — NO WAV REQUIRED
`permissions_probe` adapter doesn't transcribe audio. The scenario JSON only
describes the TCC reset + diagnostic probe.

### `07-tabitha-first-launch` — NO WAV REQUIRED
`installer_flow` adapter operates on the DMG. The smoke utterance Tabitha
records during the "Try a test recording" onboarding step is captured live via
the running app — the in-app test, not the CLI harness, owns that audio.

### `08-sam-q3-hiring.wav`
**Scenario**: 08_sam_history_search.
**Spoken phrase** (~8s):
> "Reminder to revise the Q3 hiring plan before Friday's leadership review."

```sh
say -v Alex -o 08-sam-q3-hiring.aiff "<phrase above>"
afconvert -f WAVE -d LEI16@16000 -c 1 08-sam-q3-hiring.aiff 08-sam-q3-hiring.wav
```

## Determinism notes

- whisper.cpp output for a given (model, audio, seed) is deterministic; pin
  `WHISPER_SEED=0` in the runner env so failures are reproducible.
- TTS voices change between macOS versions. Pin to macOS 14.x for fixture
  generation OR check fixtures into git LFS once stable.
- Do NOT regenerate fixtures lightly. Once committed, treat them as test
  vectors. A regenerated fixture that "passes" hides regressions.
