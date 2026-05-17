---
title: First run
---

# First run

Finish onboarding in five steps. After this page Murmur is fully wired up and ready to dictate.

## 1. Disable Apple Dictation

Apple's built-in Dictation feature also listens for a double-tap on `fn`. If you leave it on, both will fight for the same key.

1. Open **System Settings**.
2. Go to **Keyboard** → **Dictation**.
3. Toggle **Dictation** off.

![System Settings → Keyboard → Dictation off](assets/first-run/disable-apple-dictation.png)
<!-- TODO: screenshot of System Settings, Keyboard pane, Dictation toggle OFF -->

!!! tip "Don't want to disable Apple Dictation?"
    You can rebind Murmur's trigger to a different chord in [Settings → Recording](settings.md#recording). The default `fn`+`fn` is the only chord that collides with Apple Dictation.

## 2. Launch Murmur

Open Murmur from `/Applications` or Spotlight. You'll see a microphone icon appear in the menu bar.

![Menubar icon](assets/first-run/menubar-icon.png)
<!-- TODO: screenshot of the menubar with Murmur's microphone icon highlighted -->

## 3. Grant Microphone permission

The first time you record, macOS shows the standard mic permission prompt.

Click **Allow**. If you click *Don't Allow* by accident, recover it via **System Settings → Privacy & Security → Microphone → Murmur**.

![Microphone permission prompt](assets/first-run/mic-prompt.png)

See [Permissions](permissions.md) for the full picture.

## 4. Grant Accessibility permission

Murmur needs Accessibility access to:

- Listen for the global `fn`+`fn` hotkey from any app.
- Simulate the `⌘V` paste action into the focused app.

Open **System Settings → Privacy & Security → Accessibility** and toggle **Murmur** on. The app will guide you with a deep link button on first launch.

![Accessibility toggle](assets/first-run/accessibility-toggle.png)

## 5. Pick a model

Murmur ships without a model bundled, so the download happens on first launch.

1. Open **Murmur → Settings → Models**.
2. Click **Download** next to **base.en** (the default — small, fast, English-only).
3. Wait for the SHA-verified download to finish (~150 MB on a fast connection).

If you speak another language or want better accuracy, see [Models](models.md) for the full table.

## 6. Try it

1. Click any text field — Notes, Mail, a browser address bar.
2. Press `fn` twice quickly.
3. You'll see a small overlay near the notch (or top-center on non-notched Macs).
4. Speak: *"Hello, this is my first Murmur dictation."*
5. Press `fn` twice again to stop, or just stop talking — by default Murmur ends recording after ~1.5 s of silence.
6. The cleaned transcript pastes itself into the focused field.

If nothing pasted, jump to [Troubleshooting](troubleshooting.md#paste-didnt-land).

## What's next

- [Tour the Settings tabs](settings.md)
- [Add your own jargon to the Vocabulary](vocabulary.md)
- [Switch between Casual / Formal / Code prompt profiles](prompts.md)
