# Contributing to Murmur

Thanks for your interest. Murmur is a local-first Mac dictation app. Contributions of any size are welcome.

## How to file a bug

Open a bug using the [bug report template](.github/ISSUE_TEMPLATE/bug.yml). Include your macOS version, chip (Apple Silicon or Intel), Murmur version, and the Whisper model size in use. Provide exact steps to reproduce and the actual vs expected behavior.

Do not paste sensitive transcripts or personal information. Logs at `~/Library/Logs/Murmur/` never contain transcript content and are safe to attach as-is.

## How to suggest a feature

Open a request using the [feature template](.github/ISSUE_TEMPLATE/feature.yml). Search prior issues and Discussions first to avoid duplicates. If your idea overlaps with the v1.0 design spec, link it and explain the delta.

## Local development

Build the app:

```bash
bash app/Scripts/build_app.sh
```

Run the test suite:

```bash
cd app && swift test
```

## Coding style

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- SwiftLint warnings are treated as errors in CI. Fix them before pushing.
- Prefer small, named types over large monolithic ones.
- Public API gets doc comments. Private helpers get doc comments when intent isn't obvious from the name.

## Tests

Every PR adds or updates a test covering the change. CI runs the matrix on macOS 13 and macOS 14. A PR that breaks the matrix will not merge.

## Commit message style

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) with a module scope. Example:

```
feat(settings): add hotkey picker
fix(transcription): handle empty audio buffer
docs(privacy): clarify Apple Events scope
```

## Pull requests

- Title under 70 characters, present tense, no trailing period.
- Body answers three questions: what changed, why, how you tested it.
- One purpose per PR. Smaller PRs ship faster.
- Link the issue it closes.
- Open as draft while iterating; mark ready for review when CI is green.

## License

By contributing you agree your contributions are licensed under the MIT License that covers the project.
