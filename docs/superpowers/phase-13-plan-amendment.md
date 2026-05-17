# Phase 13 — Verification Matrix (revised task breakdown)

This replaces the bare "dispatch 8 parallel agents" line in the implementation
plan. The harness, scenario specs, and adapter scaffolding live in
`.superpowers/drafts/phase13/` and graduate to `app/Scripts/` + `app/Scripts/scenarios/`
at the start of Phase 13 execution.

## 1. Inputs to Phase 13

- `app/build/Murmur.app` — release-mode build with `--transcribe-only`,
  `--diagnose-permissions`, and `--history-search` CLI flags wired in Phase 9.
- `app/build/Murmur-1.0.0.dmg` — notarized DMG for the installer scenario.
- `app/build/Murmur-1.0.1-test.app` + `test-appcast.xml` — only needed if we
  promote the Sparkle scenario from Tier-2 into the gating matrix
  (currently it is Tier-2 and skipped).
- The 8 scenario JSONs and the fixture WAVs documented in
  `fixtures/README.md`.

## 2. How parallel agents consume the matrix

Phase 13 dispatches 8 subagents via `subagent-driven-development`. Each agent:

1. Reads exactly one scenario JSON from `scenarios/`.
2. Runs `scenario_runner.sh <scenario.json>`.
3. Captures the JSON result line from stdout into
   `app/build/phase13/results/<id>.json`.
4. On fail: re-runs once (audio fixtures can have flaky perf), captures both
   runs, and uses `systematic-debugging` to root-cause if both fail.
5. Reports back to the dispatcher with `{status, fail_hint, transcript_snippet}`.

Agents are independent — no shared state. The dispatcher (Phase 13 lead) only
reads the 8 result JSONs at the end.

## 3. Aggregation + gate criteria

After all 8 agents return, the dispatcher runs:

```sh
jq -s '{total: length,
        pass:  map(select(.status == "pass"))  | length,
        fail:  map(select(.status == "fail"))  | length,
        skip:  map(select(.status == "skip"))  | length,
        failures: map(select(.status == "fail") | {id, exit_code})}' \
  app/build/phase13/results/*.json
```

### Gate rules for tagging v1.0.0

| Outcome                                          | Decision                                                                                                                                                                       |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 8 pass / 0 fail / 0 skip                         | Ship.                                                                                                                                                                          |
| ≥6 pass / 0 fail / ≤2 skip                       | Ship if every skip has a checked-off entry in `docs/release/v1.0.0-manual-verification.md` signed by a human reviewer within 24 hours of tag. Skips beyond 24h auto-block.      |
| Any fail                                         | Do NOT tag. File a P0, fix, rerun the failing scenarios + the two adjacent ones (because regressions cluster). Cleanup, repaste, retag.                                        |
| ≥3 skip                                          | Do NOT tag. Either fix the prereqs for the skip-causing adapters or fail the release — too much uncovered surface to call this a v1.0.0.                                       |

The CLI scenarios (01, 02, 04, 05, 08) are designed to run truly unattended in
CI. **Those five MUST pass; a fail there is a release blocker even before
counting the others.** They are the load-bearing core of the gate.

## 4. Fail-fast triage map

Each scenario carries a `fail_hint` field pointing at the most likely culprit
component. Copy the table below into the Phase 13 dispatcher prompt so failed
subagents pivot to the right file instead of bisecting blindly:

| Scenario                          | First file to inspect on fail                       |
| --------------------------------- | --------------------------------------------------- |
| 01 Devraj (code/Cursor)           | `CleanupService.swift::CodeProfile`                 |
| 02 Priya (Word/legal)             | `VocabularyEngine.swift` (literal-paren handling)   |
| 03 Jordan (AirPods)               | `AudioInputResolver.swift` (live vs. cached input)  |
| 04 Tomás (Spanish)                | `ModelResolver.swift::languageGuard`                |
| 05 Eun-ji (offline + noise)       | `WhisperPostprocessor.swift` + network-egress audit |
| 06 Yusuf (permission loss)        | `PermissionService.swift::checkOnRecordStart`       |
| 07 Tabitha (first launch)         | `OnboardingCoordinator.swift` + Gatekeeper logs     |
| 08 Sam (history search)           | `HistoryStore.swift` schema + FTS indexer           |

A failure in 01/02 most often means the same root cause: cleanup-profile
regression. A failure in 05's network-egress assertion is the only one in the
matrix that's a *trust* regression and must escalate to the founder
immediately rather than going through normal triage.

## 5. Adapters that cannot run unattended

`installer_flow.sh` and `update_path.sh` exit 77 (skip) without:

- root / passwordless sudo on the runner,
- `MURMUR_INSTALLER_INTERACTIVE=1` or `MURMUR_UPDATE_INTERACTIVE=1`,
- the prerequisite signed builds present.

For v1.0.0 we accept that scenario 07 (installer) will likely SKIP in CI and
be verified manually. Scenario 06 (`permissions_probe`) is unattended-capable
but requires the runner user to be in the admin group — set that up on the CI
mac-mini once and forget.

Sparkle update flow is intentionally NOT in the top-8 gating matrix even
though it's a Tier-2 scenario. Sparkle 2 deliberately resists scripted
confirmation of the install dialog; trying to gate v1.0.0 on it makes the gate
unreliable for the wrong reasons. Promote it once we own a mac-mini that can
do AX-automation against the Sparkle window.

## 6. Cost of running the gate

- CLI scenarios (5): ~15-25s each, ~2 minutes wall on M-series.
- `permissions_probe`: ~3s.
- `installer_flow`: ~45s when prereqs met; instant skip otherwise.
- Total CI time when fully runnable: under 5 minutes. Cheap enough to run on
  every release-candidate commit, not just at tag time.

## 7. Definition of done for Phase 13

- [ ] All 8 scenario JSONs reviewed for accuracy against `user-scenarios.md`.
- [ ] All fixture WAVs generated, committed (LFS), and reproducibility-checked.
- [ ] `scenario_runner.sh` and all 4 adapters moved from `.superpowers/drafts/phase13/`
      to `app/Scripts/scenarios/`.
- [ ] CI workflow runs the matrix on every `release/*` branch push.
- [ ] `docs/release/v1.0.0-manual-verification.md` exists with checkboxes for
      every adapter that skipped in the latest CI run.
- [ ] v1.0.0 tag created only after all gate rules in §3 pass.
