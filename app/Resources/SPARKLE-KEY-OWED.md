# Sparkle EdDSA key — owed before first public release

Murmur's Sparkle 2 integration pins update verification to an EdDSA public
key embedded in the app bundle via the `SUPublicEDKey` Info.plist value.
That value currently reads `PLACEHOLDER_REPLACE_BEFORE_FIRST_RELEASE` —
the real keypair has not been generated yet.

Before the first public release (anything past v0.x), the maintainer must:

1. **Generate the keypair once, locally.**

   The Swift Package Manager distribution of Sparkle does *not* include the
   `generate_keys` binary; it only ships with the Sparkle release tarball.
   Grab it (pinned to the version we depend on in `app/Package.swift`):

   ```sh
   VERSION=2.6.4
   curl -fSL "https://github.com/sparkle-project/Sparkle/releases/download/${VERSION}/Sparkle-${VERSION}.tar.xz" \
     | tar -xJ -C /tmp
   /tmp/bin/generate_keys
   ```

   `generate_keys` stores the private key in the macOS Keychain under
   `https://sparkle-project.org` and prints the base64 public key to stdout.

2. **Replace the placeholder in `app/Scripts/build_app.sh`.**

   The inline Info.plist that `build_app.sh` synthesises has a
   `SUPublicEDKey` entry. Swap `PLACEHOLDER_REPLACE_BEFORE_FIRST_RELEASE`
   for the exact base64 string `generate_keys` printed — no surrounding
   whitespace, no trailing newline, no quotes inside the `<string>`.

3. **Stash the private key in two places.**

   - **1Password** under `Murmur > Sparkle EdDSA private key` as a secure
     note. Title field literally that string so the release runbook can
     find it. Export the value from Keychain Access (search `sparkle`).
   - **GitHub Actions secret** named `SPARKLE_ED_PRIVATE_KEY` on the
     primary `roshanshah11/murmur` repo so the release workflow can sign
     appcast items in CI.

Once a release has shipped using this public key, the keypair must never
rotate without coordinating a forced-update path: every installed client
pins to whatever `SUPublicEDKey` was in the bundle they installed, so
swapping keys silently bricks the auto-update path for existing users.

See `docs/internal/sparkle-notes.md` for the full pipeline (appcast
generation, GitHub Pages hosting, test-update procedure, common pitfalls).
