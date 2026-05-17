---
title: Vocabulary
---

# Vocabulary

Teach Murmur the words Whisper mishears: your name, your company, the libraries you talk about. Substitutions run after transcription and before paste.

## How it works

After Whisper produces a transcript, Murmur runs a single pass of case-insensitive find / replace using your vocabulary pairs.

- **Find** is case-insensitive and matched on whole-word boundaries (`\b`).
- **Replace** is inserted exactly as you typed it. Capitalization, punctuation, internal symbols — preserved.
- Order matters: earlier rules run first. Use the drag handle to reorder.
- A single rule cannot fire twice on the same word in one transcript (no recursive replacement).

## Add a word

1. Open **Settings → Vocabulary**.
2. Click **+**.
3. Type the misheard form in **Find**.
4. Type the canonical form in **Replace**.
5. Press Return.

![Vocabulary editor](assets/vocabulary/editor.png)
<!-- TODO: screenshot of the vocabulary editor -->

## Examples

| Whisper hears | You want | Notes |
|---|---|---|
| `api` | `API` | Capital acronym |
| `chat gpt` | `ChatGPT` | Two words → one |
| `git hub` | `GitHub` | Same idea |
| `roshawn` | `Roshan` | Personal name fix |
| `kuber netty's` | `Kubernetes` | Whisper's favorite mistake |
| `react js` | `React.js` | Preserve the dot |
| `mark down` | `Markdown` | Common collapse |

## Import / export JSON

The file format is a flat array of `{find, replace}` objects.

```json
[
  {"find": "api", "replace": "API"},
  {"find": "chat gpt", "replace": "ChatGPT"},
  {"find": "roshawn", "replace": "Roshan"}
]
```

- **Export**: Settings → Vocabulary → **Export…** writes the active list to a `.json` of your choice.
- **Import**: **Import…** appends entries that don't already exist. Duplicates are skipped.

The same file is persisted alongside the app config:

```
~/Library/Application Support/Murmur/config.json
```

## Case-insensitive gotchas

Because find is case-insensitive on whole words, watch out for these traps:

- **Subwords don't match.** `cap` won't fire on `capable`. Good.
- **Punctuation does separate words.** `git,hub` matches `git hub` only if you have that pair; the comma breaks the boundary.
- **Acronyms in mid-sentence.** A rule `api → API` will fire on *"i love the api"* → *"i love the API"* — but the sentence capitalization rule in [Casual / Formal prompts](prompts.md) will then fix the leading *i*.
- **One-way only.** Vocabulary doesn't reverse on copy. If you change your mind, edit the rule and re-dictate.

## Built-in preset

**Settings → Vocabulary → Add common AI/dev terms** seeds a curated list (API, ChatGPT, GitHub, Kubernetes, TypeScript, PostgreSQL, Whisper, OpenAI, Anthropic, macOS, iOS, GitHub Copilot…). You can edit any entry after adding.

## Next

- [Prompts](prompts.md) — pair Vocabulary with the right cleanup profile.
- [Models](models.md) — a bigger model needs fewer vocabulary fixes.
