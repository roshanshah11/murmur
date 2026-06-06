# Install

Two paths. **Homebrew is strongly recommended** — it bypasses the Gatekeeper dialog entirely.

## Homebrew (recommended)

```
brew install --cask roshanshah11/murmur/murmur
```

That's it. Brew downloads the DMG, drags Murmur into `/Applications`, and the app launches cleanly the first time. Updates later: `brew upgrade --cask murmur` or use Murmur's built-in Sparkle updater.

## Direct DMG

[`Murmur.dmg`](https://github.com/roshanshah11/murmur/releases/latest/download/Murmur.dmg) · [release notes](https://github.com/roshanshah11/murmur/releases/latest)

### On first launch you'll see this Apple dialog:

> *"Apple could not verify 'Murmur' is free of malware that may harm your Mac or compromise your privacy."*

That's macOS's strict Gatekeeper for apps that aren't yet **notarised** by Apple. The 1.0.x line ships signed but not notarised — notarisation lands in 1.1.x once we enroll in the Apple Developer Program. Until then, here is the exact one-time bypass for modern macOS (Sonoma / Sequoia and later):

1. Click **Done** on Apple's error dialog.
2. Open **System Settings → Privacy & Security**.
3. Scroll all the way down to the Security section.
4. You'll see *"Murmur was blocked to protect your Mac"* (or similar wording). Click **Open Anyway**.
5. macOS may prompt for your password. Enter it.
6. A new confirmation dialog appears asking *"Are you sure you want to open it?"* — click **Open**.

That's it. macOS remembers. Every future launch is normal.

> **Note:** The older "right-click → Open" bypass no longer works on Sequoia for ad-hoc-signed apps. Use the Privacy & Security path above.

### Why is this dance necessary?

Apple's notarisation service scans every app for known malware and signs the result. Notarised apps launch silently. Murmur is signed (the code hasn't been tampered with) but not yet notarised (Apple hasn't scanned + countersigned it). This is a paperwork gap, not a quality gap — the same code ships through Homebrew without the dialog.

This goes away in **Murmur 1.1.x** after Apple Developer Program enrollment. Until then: use Homebrew if the dialog bothers you.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon **or** Intel
- ~700 MB free disk on Apple Silicon (~470 MB for the default Parakeet model; an Intel Mac needs less, e.g. 75 MB for a small Whisper model)
- A microphone (built-in is fine)
- Microphone + Accessibility permissions (Murmur will prompt during [first run](first-run.md))

## What's next

Continue to [First run](first-run.md) for the permissions walkthrough and the onboarding wizard.
