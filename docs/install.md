---
title: Install
---

# Install

Get Murmur onto a Mac in under two minutes. Choose Homebrew if you already use it; otherwise grab the DMG.

## System requirements

| Item | Minimum |
|---|---|
| macOS | 13 Ventura |
| Architecture | Apple Silicon (M1/M2/M3/M4) or Intel x86_64 |
| Disk | ~500 MB for the app + 75 MB to 3 GB per Whisper model |
| RAM | 4 GB free during transcription (large model wants 8 GB) |
| Mic | Any input device macOS recognizes |

## Homebrew { #homebrew }

The cask installs the signed and notarized app into `/Applications`.

```bash
brew install --cask roshanshah11/murmur/murmur
```

To upgrade later:

```bash
brew upgrade --cask murmur
```

To uninstall:

```bash
brew uninstall --cask murmur
```

Brew handles Gatekeeper for you — the cask is signed with Murmur's Developer ID. Launch it from Spotlight or `/Applications`.

## DMG { #dmg }

1. Download the latest `Murmur-<version>.dmg` from the [GitHub Releases page](https://github.com/roshanshah11/murmur/releases/latest).
2. Open the DMG.
3. Drag **Murmur.app** into the **Applications** alias.
4. Eject the DMG.
5. Open **Murmur** from `/Applications`.

## First Gatekeeper prompt

The signed DMG should pass Gatekeeper silently on stable macOS releases. You'll see *"Murmur is an app downloaded from the Internet. Are you sure you want to open it?"* once — click **Open**.

### If macOS refuses to open it

This usually happens on macOS betas where the Notary service is mid-update, or if the download was interrupted.

Right-click → **Open** fallback:

1. In Finder, right-click (or Control-click) **Murmur.app**.
2. Choose **Open** from the context menu.
3. Confirm **Open** in the dialog.

If that still fails, verify the download and re-grant quarantine override:

```bash
xattr -d com.apple.quarantine /Applications/Murmur.app
```

You should never need `sudo` for this; if you do, the app is in a system-protected location and you should reinstall it under `/Applications` for the current user.

## Next step

[Run Murmur for the first time](first-run.md) to disable Apple Dictation, grant permissions, and pick a model.
