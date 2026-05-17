# Changelog

All notable changes to Murmur are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — YYYY-MM-DD

First public release under the Murmur name.

### Added

- Real Settings window with seven tabs (General, Recording, Models, Vocabulary, Prompts, History, Updates).
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
