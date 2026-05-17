---
title: History
---

# History

Enable, browse, copy, re-paste, export, or wipe past dictations. History is **off by default** — Murmur stores nothing about your transcripts unless you opt in.

## Turn it on

1. Open **Settings → General**.
2. Toggle **Keep history** on.
3. Optionally set **Retention** (7 days / 30 days / 90 days / forever).

The moment you toggle it on, Murmur creates the history file:

```
~/Library/Application Support/Murmur/history.jsonl
```

One JSON object per line, append-only:

```json
{"id":"01HXYZ...","ts":"2026-05-17T09:14:02Z","profile":"casual","text":"Reschedule the design review to Thursday."}
```

Audio is never written into history — only the transcript text. The temp WAV is still deleted after every successful dictation, as described in [Privacy](privacy.md).

## Open the viewer

Menubar icon → **Show history…** (visible only when history is enabled).

![History viewer](assets/history/viewer.png)
<!-- TODO: screenshot of history viewer window -->

## What you can do

- **Search.** Fuzzy match across all stored transcripts. Searches metadata too (profile, date).
- **Copy.** ⌘C copies the selected transcript to the clipboard.
- **Re-paste.** Press ⌘V (or click **Paste**) to insert it into the last app you had focused before opening Murmur.
- **Delete one.** Select a row and press **delete**.
- **Export Markdown.** **File → Export…** writes one `.md` per entry, or a single concatenated `.md` file with H2 timestamps.
- **Clear all.** **History → Clear all…** wipes `history.jsonl` after a confirm.

## Retention

Murmur prunes entries older than your retention setting on every launch and once every 24 h while running. Set to **Forever** to opt out of pruning.

## Privacy notes

- History never leaves your Mac.
- The file is plain text. If you sync `~/Library/Application Support/` via iCloud or a backup tool, your transcripts go with it. Murmur does not sync anything on your behalf.
- See [Privacy](privacy.md) for the full data-flow diagram and the one-liner that removes every Murmur file.

## Disable + erase

```bash
# Stop Murmur first.
osascript -e 'quit app "Murmur"'

# Delete the history file.
rm -f "$HOME/Library/Application Support/Murmur/history.jsonl"
```

Or just toggle **Keep history** off in **Settings → General** and click **Erase history file**.

## Next

- [Add jargon to Vocabulary](vocabulary.md) — your history will show cleaner transcripts.
- [Switch prompt profiles](prompts.md) per-dictation if you want some entries Raw and others Formal.
