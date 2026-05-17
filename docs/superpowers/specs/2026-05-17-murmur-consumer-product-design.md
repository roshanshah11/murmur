# Murmur v1.0 — Consumer Product Design Spec

**Status:** Approved (interview locked 2026-05-17)
**Author:** Roshan Shah
**Predecessor:** FlowLite v0 (PRD bundle `01_PRD.md` … `12_References.md`)

---

## 1. Product positioning

**Murmur** is a local-first macOS dictation utility. Double-tap `fn`, speak, paste — no cloud, no account, no telemetry. Targets macOS 13+, Apple Silicon and Intel.

**Brand thesis:** "Local-first voice typing for the Mac. Yours, instantly."

**Carryover commitments (immutable, from `06_Data_Privacy_Security.md`):**

- Zero network calls in the audio/transcript path.
- Audio temp files deleted on success.
- No transcript content ever logged.
- Microphone active only during explicit recording with visible UI state.
- Accessibility permission used only for global hotkey + simulated paste.
- Config cannot execute shell.

These promises ship on the landing page, the README, and `PRIVACY.md`.

---

## 2. Decisions locked from interview

| Question | Decision |
|---|---|
| Brand name | **Murmur** |
| Repo | Rename `roshanshah11/voicemodel` → `roshanshah11/murmur` (GitHub auto-redirects) |
| Distribution | GitHub Releases (signed/notarized DMG) **and** Homebrew cask |
| Monetization | Free + open source forever. MIT license. Optional GitHub Sponsors. |
| Auto-update | Sparkle 2 with EdDSA-signed appcast hosted on GitHub Pages |
| Strategy | Evolve in place from current SwiftPM target |
| Feature scope for v1.0 | Settings UI, History viewer window, Vocabulary/Prompt library, Multi-language model picker |
| App Store | Out of scope (sandbox forbids the global-fn paste model) |

---

## 3. Goals and non-goals

### Goals (v1.0)

1. Anyone with a Mac can install Murmur in one command (`brew install --cask murmur`) or one download (signed DMG).
2. First launch walks the user through Microphone + Accessibility permissions and verifies Whisper is set up.
3. A real Settings window replaces hand-edited JSON.
4. A History window lets users browse, search, copy, and re-paste past dictations (off by default; opt-in).
5. Vocabulary and Prompt rules are editable in-app.
6. Users pick model size (tiny / base / small / medium / large) and language from a dropdown; Murmur downloads models with a progress UI.
7. Sparkle ships in-app updates from a signed appcast.
8. Full docs published on GitHub Pages: user guide, permissions, FAQ, troubleshooting, architecture, development, contributing, security, privacy.
9. Parallel verification agents confirm 8+ realistic user scenarios end-to-end before tagging `v1.0.0`.

### Non-goals

- Cloud transcription. Cloud LLM cleanup.
- Mac App Store distribution.
- Windows / Linux / iOS ports.
- Real-time streaming partials.
- Team accounts, sync, cloud history.
- Auto-send (Slack/email send-on-keyword).
- Paid tier of any kind.

---

## 4. Repository layout (final)

```
/
├── README.md                  # Consumer landing in the repo (badges, screenshot, install, demo)
├── LICENSE                    # MIT
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── PRIVACY.md
├── .gitignore
├── .github/
│   ├── workflows/
│   │   ├── ci.yml             # Build + test on PR/main
│   │   ├── release.yml        # Tag-triggered: signed DMG, notarize, Sparkle appcast
│   │   └── pages.yml          # Build + deploy /website to gh-pages
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug.yml
│   │   ├── feature.yml
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── FUNDING.yml
├── app/                       # was implementation/
│   ├── Package.swift
│   ├── Sources/Murmur/
│   │   ├── main.swift
│   │   ├── App/                 # AppDelegate, AppState, AppContext, AppPaths
│   │   ├── Audio/               # AudioRecorder
│   │   ├── Transcription/       # WhisperRunner, ModelManager
│   │   ├── Text/                # TextCleaner, Vocabulary, PromptLibrary
│   │   ├── Insertion/           # PasteboardInserter
│   │   ├── Hotkey/              # HotkeyMonitor
│   │   ├── History/             # HistoryStore
│   │   ├── Volume/              # VolumeController
│   │   ├── Notify/              # Notifier
│   │   ├── Config/              # Config, Migration
│   │   ├── Log/                 # Log
│   │   ├── Update/              # SparkleUpdater
│   │   ├── UI/
│   │   │   ├── Notch/           # NotchIndicator (split), SpectrumBarsView
│   │   │   ├── Settings/        # SettingsWindow (SwiftUI Settings scene)
│   │   │   ├── History/         # HistoryWindow
│   │   │   ├── Vocabulary/      # VocabularyEditor, PromptLibraryEditor
│   │   │   ├── Onboarding/      # OnboardingWindow (first-launch wizard)
│   │   │   └── About/           # AboutWindow
│   │   └── CLI/                 # CLI argument parsing
│   ├── Resources/
│   │   ├── Assets.xcassets/     # AppIcon (1024 + every size), Brand colors
│   │   ├── config.example.json
│   │   ├── sample.wav
│   │   └── Info.plist           # Bundle ID com.murmur.app, SUFeedURL, NS* usage descriptions
│   ├── Scripts/
│   │   ├── bootstrap_whisper_cpp.sh
│   │   ├── build_app.sh
│   │   ├── package_dmg.sh        # New: create signed, notarized DMG
│   │   ├── sign_and_notarize.sh  # New: codesign + notarytool wrapper
│   │   ├── publish_appcast.sh    # New: generate_appcast wrapper
│   │   ├── run_local_smoke_test.sh
│   │   └── setup_signing.sh
│   ├── Tests/MurmurTests/
│   │   ├── ConfigTests.swift
│   │   ├── ConfigMigrationTests.swift
│   │   ├── HistoryStoreTests.swift
│   │   ├── ModelManagerTests.swift
│   │   ├── TextCleanerTests.swift
│   │   ├── VocabularyTests.swift
│   │   ├── PromptLibraryTests.swift
│   │   └── WhisperRunnerTests.swift
│   └── build/                   # gitignored
├── docs/                       # MkDocs-Material site for GitHub Pages
│   ├── index.md
│   ├── install.md
│   ├── first-run.md
│   ├── permissions.md
│   ├── settings.md
│   ├── history.md
│   ├── vocabulary.md
│   ├── prompts.md
│   ├── models.md
│   ├── troubleshooting.md
│   ├── faq.md
│   ├── privacy.md
│   ├── architecture.md
│   ├── development.md
│   ├── superpowers/specs/      # design docs (this file)
│   └── assets/                 # screenshots, hero image
├── website/                    # Marketing landing (single page) — same domain
│   ├── index.html
│   ├── style.css
│   └── og-image.png
├── HomebrewFormula/
│   └── murmur.rb                # Homebrew cask
└── brand/
    ├── icon.svg                 # master icon
    ├── icon-mask.png            # 1024 master raster
    ├── wordmark.svg
    └── palette.md               # Murmur brand palette (mute red + warm whites)
```

Old PRD docs (`01_PRD.md` … `12_References.md`) move under `docs/specs/v0/` for archival reference, not deletion.

---

## 5. FlowLite → Murmur migration

### Code rename (find/replace + targeted edits)

Per audit, 31 string + identifier matches across 6 files plus path constants. Migration is mechanical:

1. **String find/replace** in `CLI.swift`, `AppState.swift`, `Notifier.swift`, `main.swift`, `PasteboardInserter.swift`: `FlowLite` → `Murmur`, `flow-lite` → `murmur`, `Flow Lite` → `Murmur`.
2. **Identifier renames:** `FlowLiteState` → `MurmurState` (AppState.swift). `import FlowLite` in tests → `import Murmur`.
3. **`Package.swift`:** target name `FlowLite` → `Murmur`, test target `FlowLiteTests` → `MurmurTests`, path `Sources/FlowLite` → `Sources/Murmur`.
4. **Bundle ID:** `dev.local.flow-lite` → `com.murmur.app`. Update `setup_signing.sh` and `build_app.sh`.
5. **AppPaths struct** (new file, `App/AppPaths.swift`): centralize `appNameDirectory = "murmur"`, `logsDirectory`, `tempDirectory`, `modelsDirectory`. Replace 3 hardcoded path sites in `Config.swift` and the `flow-lite-YYYY-MM-DD.log` pattern in `Log.swift`.

### User data migration (one-time, transparent)

Murmur switches to Apple-conventional locations:

- Config + history + models: `~/Library/Application Support/Murmur/`
- Logs: `~/Library/Logs/Murmur/`
- Temp audio: `~/Library/Caches/Murmur/`

On first launch under the Murmur name:

- If `~/.flow-lite/config.json` exists and `~/Library/Application Support/Murmur/config.json` does not: copy `config.json`, copy `history.jsonl` if present, copy any model files in `~/.flow-lite/models/` into the new models dir, write a `.migrated` marker into the old dir, and log the migration. Do not delete `~/.flow-lite/` (user can rm later).
- `~/Library/Caches/FlowLite/` → ignore (temp only).
- `Scripts/uninstall.sh` published in docs removes Murmur data when requested.
- Write `ConfigMigrationTests.swift` covering both first-time and legacy-data migration paths.

---

## 6. Architecture changes

### Existing seams (preserve)

`AppState` stays as the central orchestrator. `AudioRecorder`, `WhisperRunner`, `TextCleaner`, `PasteboardInserter`, `HistoryStore`, `VolumeController` keep their public surfaces. `HotkeyMonitor` and `Notifier` unchanged.

### New modules

| Module | Purpose | Public surface |
|---|---|---|
| `App/AppPaths.swift` | Centralized filesystem layout | `static var appSupportDirectory: URL`, `var modelsDirectory`, etc. |
| `Update/SparkleUpdater.swift` | Manage Sparkle Updater + check menu item | `init()`, `checkForUpdates()` |
| `Transcription/ModelManager.swift` | Download/select Whisper models | `available`, `installed`, `download(model:)`, `select(model:)` |
| `Text/Vocabulary.swift` | Replace `Config.customVocabulary: [String: String]` with structured store + tests | `entries`, `apply(to:)`, CRUD |
| `Text/PromptLibrary.swift` | Named cleanup profiles (Casual / Formal / Code / Raw) | `Profile`, `active: Profile`, `apply(to:)` |
| `UI/Settings/SettingsWindow.swift` | SwiftUI `Settings { … }` scene with tabs: General, Recording, Vocabulary, Prompts, Models, Updates, About | `static func open()` |
| `UI/History/HistoryWindow.swift` | Browsable list of past entries, search, copy, re-paste | `static func open()` |
| `UI/Vocabulary/VocabularyEditor.swift` + `PromptLibraryEditor.swift` | CRUD on rules with live preview against `sample.wav` transcript | nested in Settings |
| `UI/Onboarding/OnboardingWindow.swift` | First-launch wizard: welcome → mic permission → accessibility permission → model download → trigger test → done | `static func openIfNeeded()` |
| `UI/About/AboutWindow.swift` | Version, link to website, license, sponsor, "Check for updates" | `static func open()` |

### File-size remediation

`NotchIndicator.swift` (871 LOC) splits into:

- `UI/Notch/NotchIndicator.swift` (state machine + panel lifecycle, ~250 LOC)
- `UI/Notch/NotchPillView.swift` (custom NSView with masked path)
- `UI/Notch/NotchPalette.swift` (colors, spacing, durations)
- `UI/Notch/NotchState.swift` (shared enum)
- `UI/Notch/SpectrumBarsView.swift` (already separate)

### State machine extension

`MurmurState` adds:

- `.firstRun` → drives onboarding
- `.downloadingModel(progress: Double)` → drives notch progress bar + Settings progress
- `.checkingForUpdate` and `.updateAvailable(version:)` → drives notch + menubar

---

## 7. New feature surfaces — detailed

### 7.1 Settings window (SwiftUI)

Single `Settings` scene with seven tabs:

- **General:** Launch at login (LaunchAtLogin SwiftPM lib), menubar icon style, show notch overlay toggle, music auto-pause toggle.
- **Recording:** Hotkey picker (default double-tap fn, alternatives: F6 hold-to-talk, ⌘⇧Space toggle), input device picker, sample-rate, max recording length.
- **Vocabulary:** Live-editable table of `from → to` rules. Import/Export JSON. Live preview against last transcript.
- **Prompts:** Profile list (Casual, Formal, Code, Raw, custom). Each profile = ordered cleanup rules + filler-word policy + capitalization policy. Active profile shows badge.
- **Models:** Whisper model picker (tiny / base / small / medium / large; .en variants and multilingual). Disk size, download button, progress bar, selected indicator. Language picker (auto-detect default).
- **Updates:** Sparkle: "Check for updates" button, "Automatically check" toggle, "Update channel" (stable / beta) picker, last-checked timestamp.
- **About:** Version, build, website link, GitHub link, license link, donate link, credits.

### 7.2 History window

Off by default (privacy first). Toggle in Settings → General enables it. When enabled:

- Rolling JSONL file at `~/Library/Application Support/Murmur/history.jsonl` (Apple-blessed location, not `~/.murmur`).
- Window shows last 500 entries with: timestamp, target app, duration, character count, full transcript.
- Search across transcripts (live).
- Per-row actions: copy, re-paste, delete, mark favorite.
- Bulk: export selected as Markdown, clear all.
- Encrypted-at-rest option (uses macOS Data Protection via NSFileProtectionComplete on first-run when FileVault is on).

### 7.3 Vocabulary + Prompts

Vocabulary is replace-text rules. Prompts are *behavioral* cleanup profiles (no LLM — these are deterministic transforms compiled from rules):

- **Raw:** Pure Whisper output, no cleanup.
- **Casual:** Remove "um/uh/like", smart-quotes, ensure terminal punctuation.
- **Formal:** Casual + capitalize sentence starts + expand contractions optionally + period-space-period normalization.
- **Code:** Preserve verbatim spacing, convert spoken operators ("equals equals" → "=="), don't auto-capitalize, keep underscores.

Profile swap via menubar submenu and via Settings.

### 7.4 Model picker + download UI

- Hosted models from Hugging Face (`ggml-*.bin` files).
- Disk-size column shown before download.
- Download via `URLSession.download` to `~/Library/Application Support/Murmur/Models/` with SHA-256 verification against a manifest shipped in the bundle.
- Background download with notch progress bar (new `MurmurState.downloadingModel(progress:)`).
- Selecting a model writes `Config.modelPath` and `Config.modelName`.

### 7.5 Sparkle auto-updater

- SwiftPM dependency: `https://github.com/sparkle-project/Sparkle`, version pin to 2.x.
- `Info.plist` keys:
  - `SUFeedURL` → `https://murmur.app/appcast.xml` (or GitHub Pages URL until custom domain).
  - `SUPublicEDKey` → generated once via `generate_keys`, stored in a 1Password secret, ed25519 public key committed to repo.
  - `SUEnableInstallerLauncherService` → false (no privileged install).
- `Update/SparkleUpdater.swift` wraps `SPUStandardUpdaterController` and exposes `checkForUpdates()` for Settings + menubar.
- Appcast hosted at `gh-pages/appcast.xml`. CI `release.yml` job runs `generate_appcast` and `sign_update`, commits to `gh-pages` branch.
- Update channel selector reads `SUFeedURL` from a small per-channel `Info.plist` companion; default stable, opt-in beta.

### 7.6 Onboarding window (first-launch wizard)

Six steps, SwiftUI:

1. Welcome ("Murmur — local-first voice typing").
2. How it works (double-tap fn, speak, paste — animated diagram).
3. Microphone permission (AVAudioApplication.requestRecordPermission).
4. Accessibility permission (deep-link to System Settings, polls until granted).
5. Pick a model (default base.en, allow override). Download progress.
6. Trigger test: prompts user to double-tap fn, speak a phrase, see it land in a built-in TextField. Confirms end-to-end works before exit.

Skippable but reopens until step 5 is done (else app cannot transcribe). Triggers on first launch and from Settings → About → "Run setup again".

---

## 8. Distribution

### 8.1 Signed + notarized DMG

GitHub Actions `release.yml` (tag push `v*.*.*`):

1. Checkout, set up Swift toolchain.
2. Bootstrap whisper.cpp (cached).
3. `Scripts/build_app.sh` → produces `Murmur.app`.
4. `Scripts/sign_and_notarize.sh`:
   - `codesign --deep --options runtime --timestamp -s "$DEVELOPER_ID" Murmur.app`
   - Hardened runtime entitlements: `com.apple.security.device.audio-input`, `com.apple.security.automation.apple-events` for Spotify/Music control.
   - `xcrun notarytool submit Murmur.zip --keychain-profile murmur-notary --wait`
   - `xcrun stapler staple Murmur.app`
5. `Scripts/package_dmg.sh`: create DMG (`create-dmg` Homebrew tool), codesign DMG itself, staple, hash.
6. Upload DMG + SHA-256 + `appcast.xml` to GitHub Release.
7. `Scripts/publish_appcast.sh`: `generate_appcast` against the release archive, commit to `gh-pages`.
8. Bump Homebrew cask: open PR against `homebrew-murmur` tap (or self-hosted tap at `roshanshah11/homebrew-murmur`) updating SHA + version.

Secrets in GitHub Actions:
- `DEVELOPER_ID_CERT_P12` (base64 of .p12)
- `DEVELOPER_ID_CERT_PASSWORD`
- `APPLE_ID`, `APPLE_TEAM_ID`, `APP_SPECIFIC_PASSWORD`
- `SPARKLE_ED_PRIVATE_KEY` (base64)

### 8.2 Homebrew cask

`HomebrewFormula/murmur.rb`:

```ruby
cask "murmur" do
  version "1.0.0"
  sha256 "<auto-bumped by CI>"
  url "https://github.com/roshanshah11/murmur/releases/download/v#{version}/Murmur-#{version}.dmg"
  name "Murmur"
  desc "Local-first macOS voice dictation"
  homepage "https://murmur.app"
  app "Murmur.app"
  zap trash: [
    "~/Library/Application Support/Murmur",
    "~/Library/Caches/Murmur",
    "~/Library/Preferences/com.murmur.app.plist",
  ]
end
```

Hosted in a tap at `roshanshah11/homebrew-murmur` so install command is:

```
brew install --cask roshanshah11/murmur/murmur
```

Pursue homebrew/cask main inclusion after 3 stable releases.

### 8.3 Sparkle in-app updates

Covered in §7.5.

---

## 9. Documentation suite

`docs/` rendered via MkDocs-Material, deployed to GitHub Pages on the `gh-pages` branch via `pages.yml`. Each page is short and task-oriented.

| Page | Purpose | Audience |
|---|---|---|
| `index.md` | What Murmur is, 30-sec demo GIF, "Get Murmur" button | Anyone landing on docs |
| `install.md` | Homebrew, DMG, requirements, first-launch sequence | Installer |
| `first-run.md` | Disable Apple Dictation, grant permissions, pick model | New user |
| `permissions.md` | What we ask for, why, how to revoke | Privacy-curious |
| `settings.md` | Tour of every Settings tab with screenshots | Daily user |
| `history.md` | Enabling history, search, export, deletion, encryption | Power user |
| `vocabulary.md` | Adding words, importing/exporting rules, gotchas | Power user |
| `prompts.md` | Profiles explained, building custom profiles | Power user |
| `models.md` | Model trade-offs, download, language support | Curious |
| `troubleshooting.md` | Common failures: paste, permissions, no audio, whisper.cpp missing | Stuck user |
| `faq.md` | Top 20 questions | Browser |
| `privacy.md` | Full data flow diagram, network policy, retention | Privacy-curious |
| `architecture.md` | Module diagram, state machine, key code pointers | Contributor |
| `development.md` | Build from source, run tests, debug logging, contributing flow | Contributor |

`README.md` at repo root is the consumer-marketing version: hero screenshot, install one-liner, three feature bullets, link to docs site. Keep it tight (~120 lines).

---

## 10. Landing page (`website/`)

Single-page static HTML at `website/index.html`. Deployed to `murmur.app` (TBD: user can register, fallback `roshanshah11.github.io/murmur`).

Sections (top → bottom):

1. **Hero:** Wordmark, one-line thesis, install command + DMG button, animated demo (GIF or `<video autoplay muted loop>`).
2. **How it works:** Three-step illustration — Hold fn → Speak → Paste.
3. **Local-first:** Privacy claims as plain bullets ("Zero network. No telemetry. Open source.").
4. **Features:** 6-tile grid — Settings, History, Vocabulary, Prompts, Models, Sparkle updates.
5. **For who:** Three persona cards — Writers, Coders, Researchers.
6. **Get Murmur:** Repeats install commands, links to GitHub.
7. **Footer:** Privacy, license, GitHub, sponsor, contact (email or GH issue).

Visual language: warm whites, mute red accent (`#C2362F`), soft shadows, monospace for code. No dark mode toggle for v1; respects `prefers-color-scheme`. No JS frameworks; vanilla CSS + minimal JS for the demo GIF swap.

---

## 11. Brand assets

- **Wordmark:** "Murmur" set in [Inter Tight Semibold or similar], slight letter-spacing.
- **Icon:** Soft squircle (1024×1024) with a stylized whisper-wave (3-bar concave waveform) in red on warm-white background, matching the notch pill aesthetic.
- **Palette:**
  - Off-white background: `#F8F4EE`
  - Warm white card: `#FFFBF5`
  - Ink: `#1A1A1A`
  - Mute red (recording / accent): `#C2362F`
  - Success green: `#3F7A4A`
  - Muted gray: `#7A7670`
- **Notch overlay** keeps current red/white palette but pulls from this shared palette.

Icon delivered as `brand/icon.svg` master + rendered into `Assets.xcassets/AppIcon.appiconset/` at all required sizes by `Scripts/render_icons.sh` using `rsvg-convert`.

---

## 12. CI/CD

GitHub Actions workflows:

### `.github/workflows/ci.yml`

Runs on PRs and main. Matrix on macOS 13 + 14.

```
- swift build -c release
- swift test
- swift run swiftlint (warnings as errors)
- scripts/run_local_smoke_test.sh (uses cached whisper.cpp + sample.wav)
```

### `.github/workflows/release.yml`

Trigger: tag matching `v*.*.*`.

Sequence: build → sign → notarize → staple → DMG → upload to Release → generate appcast → push to gh-pages → bump cask PR.

### `.github/workflows/pages.yml`

Builds MkDocs site + `website/` landing, pushes to `gh-pages` branch under `/docs/` and `/` respectively.

---

## 13. Testing & verification matrix

### Unit tests (Swift Testing or XCTest, ship with target)

- `ConfigMigrationTests` — old `~/.flow-lite` → new `~/.murmur` data move.
- `ModelManagerTests` — download, SHA verification, cancel, retry.
- `VocabularyTests` — CRUD, JSON round-trip, case-insensitive substitution.
- `PromptLibraryTests` — profile application, ordering, edge cases.
- `TextCleanerTests` — existing + new tests for each profile.
- `WhisperRunnerTests` — existing.
- `HistoryStoreTests` — existing + opt-in toggle behavior.
- `AppPathsTests` — single-source-of-truth invariants.

### Integration / scenario tests (manual scripts)

`Scripts/scenario_runner.sh <scenario.json>` records a 5-second sample, runs the pipeline headless, asserts on the cleaned transcript. Used by both CI smoke test and verification agents.

### Parallel agent verification (gating release)

Per goal directive, 8 parallel agents each simulate a realistic user end-to-end against the installed `.app`:

1. **Writer drafting a blog post in Notion** — long-form dictation, mid-sentence pause, multi-paragraph.
2. **Engineer dictating a code comment in Cursor** — Code profile, mixed identifiers + prose.
3. **Researcher dictating quotes into Obsidian** — Formal profile, citation language.
4. **Slack reply on a quiet keyboard at a coffee shop** — Casual profile, short utterance, background noise.
5. **Email reply at desk with Spotify playing** — verifies music auto-pause/resume.
6. **First-time user opening a fresh install** — onboarding flow, permission prompts, model download.
7. **Power user editing vocabulary mid-session** — Settings → Vocabulary → save → re-dictate → see substitution.
8. **Update path: previous Murmur version → check-for-updates → install → relaunch** — Sparkle path.

A 9th verification agent runs the full installer path (`brew install` and DMG download both) on a clean macOS VM image.

Each agent reports pass/fail + screenshot or log artifact. Release does not tag until all green.

---

## 14. Phases / sequencing

The implementation plan (next skill: `writing-plans`) will fan these out as parallelizable workstreams. Numbering here is dependency order, not strict serial order.

1. **Phase 0 — Rename + repo hygiene.** FlowLite → Murmur in code, paths, and bundle ID. `AppPaths` extraction. Config migration. Repo rename on GitHub. Pre-commit hook + SwiftLint config. Move PRD docs to `docs/specs/v0/`.
2. **Phase 1 — Settings window scaffold.** SwiftUI Settings scene with empty tabs. Wire menubar "Settings…" item. Persist tab selection.
3. **Phase 2 — Vocabulary + Prompts engine.** Backing types, persistence, TextCleaner integration, tests.
4. **Phase 3 — Vocabulary + Prompts UI.** Tabs in Settings.
5. **Phase 4 — Model manager engine + UI.** Download with progress, SHA, cancel, picker.
6. **Phase 5 — History window.** Backing toggle + window + search + actions.
7. **Phase 6 — Onboarding wizard.** Six-step SwiftUI flow.
8. **Phase 7 — Sparkle integration.** SwiftPM dep, Info.plist keys, Updates tab.
9. **Phase 8 — Brand assets.** Icon, wordmark, palette tokens, render script.
10. **Phase 9 — Docs site.** MkDocs scaffold + every page.
11. **Phase 10 — Landing page.** `website/` static.
12. **Phase 11 — CI.** `ci.yml`.
13. **Phase 12 — Release pipeline.** `release.yml` + signing + notarization + Sparkle + Homebrew tap.
14. **Phase 13 — Verification agents.** Run 9-agent matrix, gate v1.0.
15. **Phase 14 — Tag v1.0.0** and announce.

Phases 1–8 can parallelize after Phase 0. Phases 9–12 can parallelize once Phase 0 is in. Phase 13 gates Phase 14.

---

## 15. Open trade-offs noted, deferred

- **Custom domain `murmur.app`** — out of pocket; deferred until v1.0 ships. Use `roshanshah11.github.io/murmur` until then.
- **Notarization** requires Apple Developer Program ($99/yr). Spec assumes user signs up; if not, fallback is ad-hoc signed DMG with documented Gatekeeper bypass (which README already documents).
- **Hold-to-talk** mode (PRD v1 goal) — implemented as a hotkey-picker option, but default stays double-tap fn for backwards compat with current users.
- **Local LLM cleanup** (PRD v2 goal) — explicitly deferred. Prompts library covers the deterministic subset.

---

## 16. Success criteria

Murmur v1.0 ships when **all** of these are true:

- [ ] `brew install --cask roshanshah11/murmur/murmur` installs and runs on a clean macOS 13+ machine without warnings.
- [ ] DMG download → drag-to-Applications opens without "unidentified developer" prompt.
- [ ] First launch completes the 6-step onboarding without errors on a fresh user account.
- [ ] All 9 verification agents pass green.
- [ ] Sparkle correctly delivers a `v1.0.1` test update from `v1.0.0`.
- [ ] Docs site live and crawlable.
- [ ] All listed unit tests pass on macOS 13 and 14 CI matrix.
- [ ] README, LICENSE, CHANGELOG, CONTRIBUTING, SECURITY, PRIVACY all present and not boilerplate.
- [ ] No occurrence of "FlowLite" or "flow-lite" remains in code, docs, or website (grep-checked in CI).
