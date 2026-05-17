---
title: Troubleshooting
---

# Troubleshooting

Twelve common failure modes, each with a probable cause and a fix. If yours isn't here, attach the latest log file (`~/Library/Logs/Murmur/murmur-YYYY-MM-DD.log`) to a GitHub issue.

## Paste didn't land { #paste-didnt-land }

**Cause.** Accessibility permission missing or the frontmost window isn't accepting keystrokes (e.g. a sandboxed app, an admin password prompt, or 1Password's auto-lock screen).

**Fix.**

1. Open **System Settings → Privacy & Security → Accessibility**. Confirm **Murmur** is toggled on.
2. Click into a plain text field (Notes, TextEdit).
3. Retry the dictation. If the same transcript pastes there, the previous app was the problem.
4. The transcript is on the clipboard either way — `⌘V` manually as a fallback.

## No audio captured { #no-audio }

**Cause.** Microphone permission denied, the wrong input device is selected, or the system input volume is at 0.

**Fix.**

1. **System Settings → Privacy & Security → Microphone → Murmur** → on.
2. **Settings → Recording → Input device** → match the mic you're speaking into.
3. **System Settings → Sound → Input** → input level should bounce when you speak. If it's flat, the issue is upstream of Murmur.

## Double-`fn` does nothing { #double-fn-nothing }

**Cause.** Apple Dictation is still enabled (it captures the same chord), Accessibility is off, or the chord was rebound.

**Fix.**

1. **System Settings → Keyboard → Dictation** → off.
2. **Settings → Recording → Hotkey** → confirm `fn`+`fn`.
3. **System Settings → Privacy & Security → Accessibility → Murmur** → on.
4. Quit + relaunch Murmur. The global key monitor reattaches at launch.

## Whisper output is empty { #whisper-empty }

**Cause.** Audio captured but silent (mic muted at hardware level), or the recording was shorter than ~0.3 s.

**Fix.**

1. Try the macOS **Voice Memos** app and record briefly. If that's also silent, the mic is the problem.
2. Speak immediately on the next attempt — Whisper needs at least a few hundred ms of voiced audio to produce text.
3. Check the latest log line for `RMS=` values. Anything below `-55 dBFS` is effectively silence.

## Music doesn't auto-pause { #music-no-pause }

**Cause.** Spotify isn't running, or you're on a version of macOS where Music's media-remote endpoint changed.

**Fix.**

1. Confirm **Settings → General → Pause music during recording** is on.
2. Launch the music app before recording.
3. If still broken, file a log — Murmur uses public AppleScript via Apple Eventss that occasionally shift in macOS minor releases.

## Notch overlay invisible on a non-notched Mac { #notch-overlay-invisible }

**Cause.** The overlay positions to the notch region. On Macs without a notch it falls back to a centered top-of-screen banner. If you have a notched Mac connected to an external display and the notched display is mirrored / off, the overlay can target a hidden screen.

**Fix.**

1. **Settings → General → Notch overlay** → set to **Top center** to bypass notch detection.
2. Or: System Settings → Displays → make the built-in MacBook display active, then retry.

## Very long recording timeouts { #long-recording-timeout }

**Cause.** **Settings → Recording → Maximum recording length** is set to the default 120 s. Anything longer cuts off.

**Fix.**

1. **Settings → Recording → Maximum recording length** → bump to your needed value (up to 600 s).
2. For multi-minute dictations, use a bigger model — `tiny` and `base` degrade on long monologues.

## Model download stuck { #model-download-stuck }

**Cause.** Flaky connection, corporate proxy, or a Hugging Face hiccup.

**Fix.**

1. **Settings → Models** → click **Cancel** on the stuck row, then **Download** again.
2. Verify the partial file was removed:
   ```bash
   ls -lh "$HOME/Library/Application Support/Murmur/Models/"
   ```
   Anything ending in `.part` is a stale partial. Delete it.
3. Try a different network. Hugging Face occasionally rate-limits aggressive resumes.

## Sparkle update fails { #sparkle-fails }

**Cause.** The appcast couldn't be reached, or the signature didn't validate (Murmur refuses tampered updates).

**Fix.**

1. Confirm internet reachability to `roshanshah11.github.io`.
2. **Settings → Updates → Check now**. The log line will show the HTTP status.
3. If signature validation fails, the build itself is broken — open a GitHub issue. Do **not** bypass.

## Murmur appears to record forever { #recording-forever }

**Cause.** Silence detection threshold too low (Murmur thinks ambient noise is speech), or **Hold-to-talk** mode is on and the key was released elsewhere.

**Fix.**

1. **Settings → Recording → Auto-stop threshold** → bump from -38 to -32 dBFS in noisy rooms.
2. **Hold-to-talk** off if you don't want it.
3. Press `fn`+`fn` again to force-stop.

## Menubar icon disappeared { #menubar-gone }

**Cause.** macOS hides menubar items behind the notch when overflow is severe (most often with Bartender / Hides installed), or Murmur crashed.

**Fix.**

1. `ps aux | grep Murmur` to confirm it's running.
2. If it isn't, relaunch from `/Applications`. The latest log will show why it exited.
3. If it is running but invisible, drag-reorder menubar items (⌘-drag in macOS 14+) or temporarily disable the third-party menubar manager.

## Pasting into Terminal escapes characters weirdly { #terminal-paste-weird }

**Cause.** Terminal's bracketed paste mode + a transcript containing newlines (Code profile especially).

**Fix.**

1. Use the [**Casual**](prompts.md#casual) or **Raw** profile when dictating into Terminal.
2. Or paste with `⌘⌥V` (some terminals bind that to literal paste).

## Still stuck

```bash
open "$HOME/Library/Logs/Murmur/"
```

Attach the latest log to a [GitHub issue](https://github.com/roshanshah11/murmur/issues/new). Logs never contain transcript text — see [Privacy](privacy.md).
