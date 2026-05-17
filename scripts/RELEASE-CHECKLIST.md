# Murmur v1.0 Release Checklist

Every step the `release-setup.sh` helper **cannot** automate. Work top-down — later
steps depend on the secrets and certificates produced earlier.

Status legend: `M` manual · `A` automated (by release.yml / setup script) · `P` partly automated.

---

## 1. Apple Developer Program enrollment
- **Status:** M
- **Time:** ~30 min form + 24–48 h Apple approval
- **Depends on:** valid Apple ID, $99 USD, US bank-card for D-U-N-S if enrolling as org
- **Action:** [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/). Personal enrollment is fastest; org requires a D-U-N-S number (free, ~3 business days).
- **Gate:** can't generate any signing certs until Apple sends the approval email.

## 2. Generate Developer ID Application certificate + export .p12
- **Status:** M
- **Time:** ~15 min
- **Depends on:** step 1 complete
- **Action:**
  1. Xcode → Settings → Accounts → Manage Certificates → `+` → **Developer ID Application**.
  2. Keychain Access → My Certificates → right-click the new cert → **Export** → `.p12` with a strong passphrase.
  3. `base64 -i DeveloperID.p12 | pbcopy` — you'll paste this into the GitHub secret.
- **Gate:** notarization will fail without this. Keep the .p12 + passphrase in 1Password.

## 3. App-specific password for notarytool
- **Status:** M
- **Time:** 5 min
- **Depends on:** Apple ID with 2FA enabled
- **Action:** [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords → `+` → label `murmur-notarize`. Copy once, store in 1Password.
- **Gate:** `xcrun notarytool submit` rejects regular passwords.

## 4. Sparkle EdDSA keys
- **Status:** M (one-time)
- **Time:** 5 min
- **Depends on:** `Sparkle.framework` checked out (Carthage/SPM artifact bundle)
- **Action:**
  ```bash
  ./Sparkle/bin/generate_keys
  ```
  - Public key → paste into `build_app.sh` as `SUPublicEDKey` Info.plist value.
  - Private key → 1Password **and** GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY`.
- **Gate:** lose the private key and every shipped Murmur stops accepting updates. Back it up before pushing the public key to git.

## 5. GitHub Actions secrets
- **Status:** M (config) · A (consumed by release.yml)
- **Time:** ~10 min
- **Depends on:** steps 2, 3, 4
- **Action:** `gh secret set <NAME>` for each:
  | Secret | Source | Used by |
  | --- | --- | --- |
  | `DEVELOPER_ID_CERT_P12` | base64 of the .p12 from step 2 | codesign step in release.yml |
  | `DEVELOPER_ID_CERT_PASSWORD` | passphrase you chose in step 2 | imports the .p12 into a temp keychain |
  | `DEVELOPER_ID_IDENTITY` | e.g. `Developer ID Application: Roshan Shah (TEAMID)` | `codesign --sign` arg |
  | `APPLE_ID` | your Apple Developer email | notarytool |
  | `APPLE_TEAM_ID` | 10-char team ID from Apple Developer portal | notarytool |
  | `APPLE_APP_PASSWORD` | app-specific password from step 3 | notarytool |
  | `SPARKLE_ED_PRIVATE_KEY` | private key from step 4 | `sign_update` in release.yml |
  | `HOMEBREW_TAP_TOKEN` | fine-grained PAT with `contents:write` on `homebrew-murmur` | pushes updated formula |
  | `KEYCHAIN_PASSWORD` | random string (used only inside the runner) | temp keychain create/unlock |
- **Gate:** any missing secret → release.yml fails halfway, often after notarization started. Run `gh secret list` before tagging.

## 6. SwiftLint passes locally
- **Status:** M
- **Time:** 2 min
- **Depends on:** `brew install swiftlint`
- **Action:** from repo root: `swiftlint --strict`. Fix every warning — `--strict` treats them as errors, matching the CI workflow.
- **Gate:** branch protection blocks merge to `main` if SwiftLint fails on PR.

## 7. Smoke test on a clean macOS user account
- **Status:** M
- **Time:** 20–30 min
- **Depends on:** signed DMG from a `--dry-run` of `build_app.sh`
- **Action:** System Settings → Users & Groups → add a fresh standard user → log in → install DMG → run through onboarding → record audio → confirm transcription, mute behavior, and Sparkle "Check for Updates" all work without touching the home directory of your dev account.
- **Gate:** catches "works on my machine" issues (TCC prompts, missing permissions plist entries, hard-coded paths).

## 8. Hard-gate scenarios via `scenario_runner.sh`
- **Status:** M (run) · P (assertions automated inside the runner)
- **Time:** ~45 min
- **Depends on:** Murmur installed from the signed DMG (step 7)
- **Action:** `./scripts/scenario_runner.sh --all`. The 5 mandatory scenarios:
  1. Cold launch + first-recording onboarding
  2. Mid-meeting hotkey toggle (no audio glitch)
  3. Spotify ducking on/off
  4. Sparkle update from a previous build
  5. Crash + relaunch (verify autosaved transcript)
- **Gate:** any scenario reporting `FAIL` blocks the release. Capture the runner's log for the release notes.

## 9. Tag v1.0.0 + push
- **Status:** M (tag) → A (release.yml takes over)
- **Time:** 1 min to tag, 15–25 min for the pipeline
- **Depends on:** steps 1–8 green; `CHANGELOG.md` updated; `release-setup.sh` ran cleanly.
- **Action:**
  ```bash
  git tag -s v1.0.0 -m "Murmur 1.0.0"
  git push origin v1.0.0
  ```
  Watch the pipeline: `gh run watch`. It builds, signs, notarizes, staples, generates the Sparkle appcast, publishes the draft GitHub release, and opens a PR against `homebrew-murmur`.
- **Gate:** **signed** tag (`-s`). Unsigned tags trip our release.yml verification step.

## 10. Smoke-test the actual published DMG
- **Status:** M
- **Time:** 15 min
- **Depends on:** step 9 succeeded; you've publish-from-draft on the GitHub release page.
- **Action:** from another Mac (or the clean user account from step 7), download the published DMG from the GitHub Releases page, verify Gatekeeper accepts it with no right-click bypass: `spctl -a -vvv -t install /Volumes/Murmur/Murmur.app` should print `accepted` and `source=Notarized Developer ID`.
- **Gate:** if Gatekeeper rejects, **do not** announce — pull the release back to draft, investigate notarization log via `xcrun notarytool log <id>`.

## 11. Homebrew cask PR
- **Status:** P (release.yml opens it; you merge)
- **Time:** 5 min
- **Depends on:** step 9. `HOMEBREW_TAP_TOKEN` secret must be valid.
- **Action:** review the auto-opened PR on `roshanshah11/homebrew-murmur` — check SHA256, version, URL match the published DMG. Merge. Verify: `brew tap roshanshah11/murmur && brew install --cask murmur` on a clean machine.
- **Gate:** if the PR didn't open, the release.yml `update-tap` job failed — usually a stale PAT.

## 12. Launch announcement
- **Status:** M
- **Time:** 1–2 h
- **Depends on:** step 10 verified, public DMG reachable.
- **Action:** post in this order so traffic lands on a working site:
  1. Show HN — title `Show HN: Murmur — offline voice notes for macOS`, link to homepage (not the GitHub repo).
  2. r/MacApps + r/macapps — short post with screenshot + brew install command.
  3. Indie newsletters — `IndieHackers`, `Ben's Bites`, `MacStories Weekly` tip line.
  4. Personal Twitter/X + Bluesky thread.
- **Gate:** make sure GitHub Sponsors button + Pages site (homepage) are live first — these are the top two clicks from Show HN.

---

## Quick reference — fully-automated steps the helper handles

`scripts/release-setup.sh` does these for you so you can stay focused on the manual list above:

- Rename `voicemodel` → `murmur`
- Re-point local `origin`
- Enable Pages on `gh-pages`
- Add branch protection on `main` (PR + 1 review + CI/SwiftLint required)
- Create `roshanshah11/homebrew-murmur`
- Confirm `.github/FUNDING.yml` is visible on origin
- Open a draft `v$VERSION` release when `VERSION=` is exported
