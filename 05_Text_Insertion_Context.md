# Text Insertion and Context Strategy

## 1. Insertion problem

The core product promise is not “transcribe audio.” It is “put useful text exactly where I was typing.”

macOS apps differ in how they handle text input. Browser fields, Electron apps, native AppKit fields, web editors, secure fields, and code editors all behave differently. For v0, the most reliable universal approach is clipboard paste.

## 2. v0 insertion method

Use pasteboard plus simulated paste:

```text
save existing clipboard string if configured
→ set clipboard to final output
→ simulate Cmd+V with CGEvent
→ optionally restore prior clipboard string after delay
```

Pros:

- Works across many apps.
- Avoids app-specific APIs.
- Simple to debug.
- Fast enough.

Cons:

- Temporarily overwrites clipboard.
- Some apps block simulated paste.
- Clipboard restore timing can be fragile.
- Secure fields should be avoided.

## 3. Safe failure behavior

Never discard output until user has access to it.

If paste may fail:

- Leave final text on clipboard.
- Show notification: `Text copied to clipboard. Paste manually if needed.`
- Log target app name and failure step.

## 4. Accessibility API future path

v1/v2 may use the Accessibility API for:

- detecting focused text fields
- reading selected text
- replacing selected text
- retrieving nearby context
- avoiding clipboard overwrite

But this should not be the first implementation. AX behavior varies across apps and web views.

## 5. Context strategy

### v0 context

Only collect:

- frontmost app name
- frontmost bundle identifier if available

Use it for logging and later style routing.

Example:

```json
{
  "frontmostApp": "Google Chrome",
  "bundleIdentifier": "com.google.Chrome"
}
```

### v1 context

Add optional app mode mapping:

```json
{
  "com.apple.mail": "email",
  "com.google.Chrome": "generic",
  "com.tinyspeck.slackmacgap": "chat",
  "com.microsoft.VSCode": "code"
}
```

### v2 context

With explicit user permission:

- selected text
- focused field value
- nearby paragraph
- email recipient if accessible
- webpage title if accessible

## 6. Why not full context in v0

Full context reading increases:

- privacy risk
- permission burden
- app compatibility issues
- debugging complexity
- risk of accidentally sending/using sensitive surrounding text

The first version should prove the core loop before reading screen content.

## 7. Target app compatibility matrix

| App / Surface | v0 expectation | Notes |
|---|---:|---|
| TextEdit | High | Best first test target |
| Apple Notes | High | Should work via paste |
| Chrome text fields | High | Includes ChatGPT, Gmail, Docs comments, web forms |
| Gmail compose | Medium-high | Web focus can be finicky but paste usually works |
| Slack | Medium-high | Electron input should accept paste |
| Discord | Medium-high | Electron input should accept paste |
| Cursor / VS Code | Medium-high | Paste should work in editor |
| Terminal | Medium | Pasting commands has risk; maybe require confirmation later |
| Password fields | Unsupported | Do not target secure fields |
| Remote desktops | Low | Events may not route as expected |

## 8. Clipboard restoration decision

Default recommendation:

```json
"restoreClipboardAfterPaste": false
```

Reason: restoring too quickly can race with paste handling in slow apps. It is safer to leave output on clipboard for v0.

v1 can add:

```json
"restoreClipboardAfterPaste": true,
"clipboardRestoreDelayMs": 1500
```

## 9. Selected text replacement

Future flow:

1. User selects rough text.
2. User dictates replacement or command.
3. App reads selected text through Accessibility API or normal clipboard copy.
4. App inserts replacement.

Alternative without AX:

```text
simulate Cmd+C
read selected text from clipboard
generate replacement
set clipboard to replacement
simulate Cmd+V
```

This is risky because it mutates clipboard twice and may fail in apps that block copy/paste.

## 10. Command mode

Future commands:

- “make this more concise”
- “turn this into bullets”
- “format this as an email”
- “rewrite this more professionally”
- “fix grammar only”

v0 should avoid command mode. It increases ambiguity and requires a stronger rewrite engine.

## 11. Insertion acceptance tests

For each target app:

1. Place cursor in field.
2. Dictate: `testing one two three`.
3. Stop recording.
4. Confirm text appears.
5. Confirm clipboard contains output if restore disabled.
6. Repeat 5 times.
7. Try while app is fullscreen.
8. Try while app is not recently focused.

Minimum v0 pass list:

- TextEdit
- Apple Notes
- Chrome text field
- ChatGPT input in Chrome
- Cursor editor
