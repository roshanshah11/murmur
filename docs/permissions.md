---
title: Permissions
---

# Permissions

See exactly what Murmur asks for, why, where to manage it, and what breaks if you say no.

Murmur requests two permissions. That's it. Nothing else.

## Microphone

**Why.** To capture audio during the brief window between you starting and stopping a recording. The mic is off at every other moment — Murmur does not maintain a hot mic.

**Where to manage.** `System Settings → Privacy & Security → Microphone → Murmur`.

**If denied.** Recording silently produces an empty WAV file, Whisper returns nothing, and Murmur shows a notch banner reading *"Microphone permission needed."* Clicking the banner opens the relevant System Settings pane.

## Accessibility

**Why.** Two reasons, both required for the core flow:

1. **Global hotkey.** Catching `fn`+`fn` outside of Murmur's own window requires Accessibility. macOS treats global key monitors as Accessibility-gated.
2. **Simulated paste.** After transcription, Murmur synthesizes a `⌘V` keystroke into the frontmost app. macOS also requires Accessibility to inject keystrokes into other apps.

**Where to manage.** `System Settings → Privacy & Security → Accessibility → Murmur`.

**If denied.** The hotkey will not fire and the transcript will not paste. Murmur falls back to copying the transcript to the clipboard so you can paste it yourself with `⌘V`. The menubar icon shows a yellow dot until Accessibility is re-granted.

## What Murmur does *not* ask for

| Permission | Why we don't need it |
|---|---|
| Full Disk Access | Murmur only writes inside its own sandbox folders. |
| Screen Recording | We never capture pixels. |
| Contacts / Calendar / Photos | We don't use them. |
| Network / Background | The only outbound call is the Sparkle update fetch (HTTPS to GitHub Pages). macOS doesn't gate that. |
| Automation (other apps) | We pause Spotify/Music via the public MediaRemote API, not AppleScript / Apple Events. |

## How to revoke everything

```bash
# Quit Murmur first.
osascript -e 'quit app "Murmur"'

# Reset every TCC entry for the app.
tccutil reset Microphone com.murmur.app
tccutil reset Accessibility com.murmur.app
```

Open the app again to re-trigger the original prompts.

## Next

[Tour the Settings tabs](settings.md) — General is where the launch-at-login toggle lives.
