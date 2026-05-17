---
title: Development
---

# Development

Build Murmur from source, run the tests, and submit a PR. The full module map is on [Architecture](architecture.md).

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Xcode Command Line Tools | latest | `xcode-select --install` |
| Swift toolchain | 5.9+ (ships with Xcode 15) | bundled |
| `cmake` | 3.21+ | `brew install cmake` |
| `git` | any recent | `brew install git` |
| `mkdocs-material` (for docs only) | latest | `pipx install mkdocs-material` |

whisper.cpp is vendored as a Swift Package dependency — no separate install.

## Clone

```bash
git clone https://github.com/roshanshah11/murmur.git
cd murmur
```

## Build the app

The helper script handles signing-disabled local builds and copies the `.app` into `build/`.

```bash
bash Scripts/build_app.sh
```

To run it without installing:

```bash
open build/Murmur.app
```

For a release build (signed, notarization-ready):

```bash
bash Scripts/build_app.sh --release
```

Release builds require a Developer ID certificate in your keychain. CI handles this automatically; local release builds without one will skip notarization.

## Run tests

```bash
swift test                    # unit + integration
swift test --filter Cleaner   # narrower
```

UI snapshot tests:

```bash
swift test --filter SnapshotTests
```

Record new snapshots:

```bash
RECORD_SNAPSHOTS=1 swift test --filter SnapshotTests
```

## Debug logging

Bump the log level via env var before launching:

```bash
MURMUR_LOG_LEVEL=debug /Applications/Murmur.app/Contents/MacOS/Murmur
```

Levels: `error`, `warn`, `info` (default), `debug`, `trace`.

Logs land in `~/Library/Logs/Murmur/`. Per the [Privacy](privacy.md) policy, transcripts are never logged — even at `trace`.

## CLI inside the bundle

```bash
/Applications/Murmur.app/Contents/MacOS/Murmur --help
/Applications/Murmur.app/Contents/MacOS/Murmur --transcribe-only sample.wav
/Applications/Murmur.app/Contents/MacOS/Murmur --record-once
/Applications/Murmur.app/Contents/MacOS/Murmur --version
```

`--transcribe-only` runs headlessly and prints to stdout; `--record-once` runs one full cycle (record + transcribe + paste) and exits.

## Contributing

We follow a lightweight, opinionated flow.

1. **Open an issue first.** Even for small changes. This avoids duplicated work and lets us discuss approach.
2. **Fork + branch.** Use branch names like `feat/per-app-prompts`, `fix/notch-non-notched`, `docs/models-table`.
3. **One concern per PR.** Smaller PRs ship faster.
4. **Conventional Commits.** Subject lines like:
   ```
   feat(prompts): add per-app override map
   fix(audio): handle null input device on Bluetooth disconnect
   docs(models): clarify medium vs medium.en
   refactor(state): extract paste path into Paster
   ```
5. **Tests required.** New code needs unit tests. State-machine transitions need transition tests. Pure functions (TextCleaner / Vocabulary) need property tests where it makes sense.
6. **CI must pass.** GitHub Actions runs `swift build`, `swift test`, `swiftformat --lint`, and a `mkdocs build --strict` on the docs.
7. **Sign your work.** `git commit -s` to add a `Signed-off-by` trailer.
8. **Open the PR against `main`.** Squash-merge is the default; keep the PR description in [the template](https://github.com/roshanshah11/murmur/blob/main/.github/pull_request_template.md).

## Style

- SwiftFormat enforces brace and import order — run `swiftformat .` before pushing.
- Public API gets doc comments (`///`). Internal helpers get inline `//` only when they need it.
- No force-unwraps in product code. `try!` is allowed only in tests for known-good fixtures.
- Avoid `Combine` outside the `StateMachine` boundary — most modules use plain async/await.

## Where the specs live

| Where | What |
|---|---|
| `docs/specs/v0/` | Archived FlowLite PRD — the project's earlier name. Useful historical context. |
| `docs/superpowers/specs/` | Active specifications. Read these before opening a feature PR. |
| `docs/superpowers/decisions/` | Architecture decision records. New ADRs welcome. |

## Documentation site

The site you're reading is built with MkDocs Material from `docs/` in the repo root.

```bash
pipx install mkdocs-material
mkdocs serve     # http://127.0.0.1:8000/
mkdocs build     # outputs to ./site
```

CI publishes to GitHub Pages on every push to `main` that touches `docs/**` or `mkdocs.yml`.

## Releasing (maintainers only)

1. Update `CHANGELOG.md`.
2. Tag: `git tag -s vX.Y.Z -m 'Murmur X.Y.Z'`.
3. Push: `git push origin vX.Y.Z`.
4. CI builds, signs, notarizes, uploads the DMG, regenerates the Sparkle appcast, and pushes the new Homebrew cask manifest.

## Next

- [Architecture](architecture.md) for the module diagram and state machine.
- [Privacy](privacy.md) for the data-flow + network surface.
