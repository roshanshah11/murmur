# Changelog

All notable changes to Murmur are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] — 2026-06-06

NVIDIA Parakeet becomes the default transcription engine on Apple Silicon.

### Added

- NVIDIA Parakeet (`parakeet-tdt-0.6b-v3`) transcription engine via the FluidAudio SDK, running in-process on the Apple Neural Engine (Core ML). Default on Apple Silicon — faster and more accurate for English than whisper.cpp.
- Engine picker in **Settings → Models** with on-demand Parakeet model download (~470 MB) and progress.
- `--engine parakeet|whisper` override for the `--transcribe-only` CLI path.

### Changed

- **Minimum macOS is now 14 (Sonoma)**, up from 13 — FluidAudio requires it. Intel Macs continue to default to whisper.cpp.
- Transcription now runs behind a `TranscriptionEngine` abstraction; **whisper.cpp remains a fully supported, selectable fallback** covering 99 languages (and the default on Intel).

## [1.0.0] — 2026-05-17

First public release under the Murmur name. The date is set when the
v1.0.0 tag is pushed (see `scripts/RELEASE-CHECKLIST.md`).

### Added

- Real Settings window with seven tabs (General, Recording, Vocabulary, Prompts, Models, Updates, About).
- Standalone History window (opt-in) for browsing, searching, and re-pasting past dictations.
- Opt-in History viewer for browsing, searching, and exporting past transcripts.
- Vocabulary library with JSON import and export for custom terminology, names, and acronyms.
- Deterministic cleanup profiles: Raw, Casual, Formal, and Code.
- Multi-language Whisper model picker with download progress UI and integrity verification.
- Sparkle in-app updates from a signed appcast hosted on GitHub Pages.
- Apple-conventional data paths under `~/Library/Application Support/Murmur/`.
- Signed and notarized DMG distributed via GitHub Releases.
- Homebrew cask via the dedicated `roshanshah11/murmur` tap.
- MkDocs documentation site.
- Marketing landing page with feature overview, screenshots, and download links.

### Changed

- Project renamed from FlowLite to Murmur across UI, bundle identifier, support paths, and docs.
- Data location migrated from `~/.flow-lite/` to `~/Library/Application Support/Murmur/` with a one-time transparent migration on first launch.

[Unreleased]: https://github.com/roshanshah11/murmur/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/roshanshah11/murmur/releases/tag/v1.0.0
