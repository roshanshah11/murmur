# Pull request

## Summary

<!-- One or two sentences describing what this PR does. -->

## Why

<!-- Motivation: what user-facing problem or internal need does this address? Link the spec or design note if there is one. -->

## How to verify

<!-- Numbered manual checks a reviewer can run locally. -->

1.
2.
3.

## Risk and rollback

<!-- Where could this break? How do we revert if it goes wrong? -->

## Linked issues

<!-- Closes #..., Refs #... -->

## Checklist

- [ ] Tests added or updated and passing locally (`swift test`).
- [ ] Documentation updated (in-repo docs, MkDocs site, or CHANGELOG as appropriate).
- [ ] v1.0 design spec respected; deviations explained in the Summary.
- [ ] No legacy `FlowLite` references reintroduced (paths, identifiers, copy, comments).
- [ ] Privacy commitments unbroken: no network in the audio path, no transcript in logs, no audio retained after success.
