# Install

Two paths. Homebrew is recommended; it handles macOS's first-launch trust prompt for you.

## Homebrew (recommended)

```
brew install --cask roshanshah11/murmur/murmur
```

That's it. Brew downloads the DMG, drags Murmur into `/Applications`, and registers it without any "unidentified developer" warning.

To update later: `brew upgrade --cask murmur`. Murmur also has Sparkle in-app updates wired up; either path works.

## Direct DMG

If you'd rather not use Homebrew, download the signed DMG from the latest release:

[`Murmur.dmg`](https://github.com/roshanshah11/murmur/releases/latest/download/Murmur.dmg) · [release notes](https://github.com/roshanshah11/murmur/releases/latest)

### On first launch you'll see "macOS cannot verify the developer"

That's expected on this 1.0.x line. Murmur is signed but not yet **notarized** by Apple — notarization arrives in a 1.1.x update once we enroll in the Apple Developer Program. Until then, the first-launch bypass is two clicks:

1. **Right-click** `Murmur.app` in your `/Applications` folder.
2. Choose **Open** from the context menu.
3. The dialog now offers an **Open** button (instead of just Cancel). Click it once.

macOS remembers your choice. Every future launch is normal.

If you'd rather use the Privacy panel:

1. Try to double-click `Murmur.app`. macOS will block it.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the security section. You'll see "Murmur.app was blocked." Click **Open Anyway**.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon **or** Intel
- ~150 MB free disk (75 MB for the default Whisper model, the rest for the app + caches)
- A microphone (built-in is fine)
- Permission to use the microphone and accessibility services (Murmur will prompt during [first run](first-run.md))

## What's next

Continue to [First run](first-run.md) to walk through permission prompts and the onboarding wizard.
