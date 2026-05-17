# homebrew-murmur

Homebrew tap for [Murmur](https://github.com/roshanshah11/murmur) — the local-first macOS voice typing app.

## Install

```sh
brew install --cask roshanshah11/murmur/murmur
```

That command implicitly taps `roshanshah11/homebrew-murmur` and installs the latest signed/notarized `Murmur.app` DMG into `/Applications`.

After the first install, Murmur updates itself in place via [Sparkle](https://sparkle-project.org) — you don't need `brew upgrade --cask` to stay current. Run it anyway if you want to make Homebrew aware of the latest version metadata.

## Uninstall

```sh
brew uninstall --cask murmur
brew uninstall --zap --cask murmur   # also clear app data, caches, prefs
```

## Reporting bugs

File issues against the main app repo, **not** this tap:

→ <https://github.com/roshanshah11/murmur/issues>

Only open issues here for problems with `brew install` itself (cask metadata wrong, SHA mismatch, etc.).

## How this tap stays current

This repo is mechanically maintained. The main repo's `release.yml` workflow:

1. Builds, signs, notarizes, and uploads `Murmur-<version>.dmg` to a GitHub Release.
2. Computes the DMG's SHA-256.
3. Runs `tap-bump-script.sh`, which clones this repo, sed-replaces the two tokens (`:auto_bump_version:`, `:auto_bump_sha256:`) in `Casks/murmur.rb`, and opens a PR titled `chore: bump Murmur to v<version>` against `main`.
4. CI on the PR runs `brew style --cask Casks/murmur.rb` and `brew audit --cask --online --new-cask Casks/murmur.rb`.
5. Maintainer merges; users see the new version on next `brew update`.

Direct edits to `Casks/murmur.rb` should be rare — prefer fixing the bump script in the main repo.

## License

MIT — same as Murmur itself.
