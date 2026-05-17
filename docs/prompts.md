---
title: Prompts
---

# Prompts

Choose how Murmur cleans the raw Whisper transcript before pasting. All four profiles are deterministic text transforms — no LLM call, no network, no surprises.

Switch the active profile in **Settings → Prompts**, or set a per-app default in **General → Per-app overrides** (planned, see [FAQ](faq.md#per-app-prompt)).

## The four profiles

### Raw

What Whisper produced, character for character. Use this for transcription work where you want to inspect verbatim output.

### Casual

Default. Aimed at chat and email.

- Capitalize the first letter of each sentence.
- Strip filler tokens (`um`, `uh`, `like`, `you know`) when they appear standalone.
- Collapse repeated whitespace.
- Trim trailing whitespace.
- Add a final period if the sentence has none and isn't a question / exclamation.

### Formal

Built on Casual. Adds:

- Expand contractions (`don't` → `do not`, `won't` → `will not`).
- Spell out integers `0` through `nine`.
- Replace `&` with `and`.
- Replace `gonna / wanna / gotta` with `going to / want to / got to`.

### Code

Built on Casual, but tuned for prose *about* code, not code itself.

- Lower-case everything outside backticks.
- Preserve backtick-wrapped tokens as-is.
- Collapse `period`, `comma`, `colon`, `semi colon`, `open paren`, `close paren`, `dash`, `arrow` into the matching punctuation (`.`, `,`, `:`, `;`, `(`, `)`, `-`, `->`).
- Replace `new line` with a literal `\n` keystroke when pasting.

## Side-by-side examples

Same raw transcript, four profiles.

**Raw transcript** (what Whisper returned):

> Um so I think we should ship the API update by friday and like don't forget to call the GitHub webhook period

| Profile | Pasted text |
|---|---|
| Raw | `Um so I think we should ship the API update by friday and like don't forget to call the GitHub webhook period` |
| Casual | `So I think we should ship the API update by Friday and don't forget to call the GitHub webhook.` |
| Formal | `So I think we should ship the API update by Friday and do not forget to call the GitHub webhook.` |
| Code | `so i think we should ship the API update by friday and don't forget to call the github webhook.` |

A more code-flavored example:

**Raw**:

> open paren list dot map open paren x arrow x plus one close paren close paren new line return result

| Profile | Pasted text |
|---|---|
| Raw | `open paren list dot map open paren x arrow x plus one close paren close paren new line return result` |
| Casual | `Open paren list dot map open paren x arrow x plus one close paren close paren new line return result.` |
| Formal | `Open paren list dot map open paren x arrow x plus one close paren close paren new line return result.` |
| Code | `(list.map(x -> x plus one))` *(then a newline keystroke)* `return result` |

!!! note "Code profile is conservative on purpose"
    It's a prose-to-prose-about-code cleaner, not a programming language transpiler. `plus one` stays as words; this is intentional so it stays predictable across Swift / Python / JS.

## Configuring

- **Active profile.** Settings → Prompts → pick one.
- **Filler-word list (Casual).** Edit the default list of strip words.
- **Contraction map (Formal).** Edit / add pairs.
- **Punctuation map (Code).** Edit / add phrase → symbol pairs.

All profile config is stored in `~/Library/Application Support/Murmur/config.json` and travels with [Vocabulary](vocabulary.md) exports.

## Order of operations

For a given dictation:

1. Whisper → raw text.
2. **Prompt profile** transforms (this page).
3. **Vocabulary** substitutions ([vocabulary](vocabulary.md)).
4. Paste.

Vocabulary runs *after* the profile, so you can use it to fix anything the profile mangled.

## Next

- [Vocabulary](vocabulary.md) for word-level overrides.
- [History](history.md) to compare profiles on the same wording over time.
