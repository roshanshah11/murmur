# Security policy

## Supported versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | Yes                |
| < 1.0   | No                 |

Security fixes land on the latest 1.0.x release. Earlier prereleases and the legacy FlowLite codebase are unsupported.

## Reporting a vulnerability

Email the maintainer at `ashah@alixpartners.com`. Do not open a public GitHub issue, Discussion, or PR that describes the vulnerability.

Include:

- A clear description of the issue and its impact.
- Steps to reproduce, ideally with a minimal proof of concept.
- Affected Murmur version and macOS version.
- Your name or handle for credit, if you want it.

Expect an acknowledgement within 72 hours. The maintainer will follow up with a triage assessment, a fix plan, and a target disclosure date.

## Scope

In scope:

- The Murmur app itself (Swift sources, bundled resources, entitlements).
- Build and release scripts under `app/Scripts/` and the GitHub Actions workflows that produce signed artifacts.
- The appcast signing pipeline and the published `appcast.xml`.

Out of scope:

- Vulnerabilities in upstream macOS, Sparkle, or whisper.cpp. Report those to the upstream maintainers directly.
- Issues that require an attacker who already has local root or full disk access.

## Disclosure

Standard window is 90 days from acknowledgement to public disclosure. The window can be expedited at the reporter's request, or extended by mutual agreement when a fix needs more time.

A coordinated advisory is published on GitHub Security Advisories when the fix ships.

## Bounty

Murmur is an independent open-source project. There is no monetary bounty. Credited disclosure in the release notes and security advisory is offered.
