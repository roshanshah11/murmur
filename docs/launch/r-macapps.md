# Murmur 1.0 — a free, MIT-licensed, fully local dictation app for writers and coders on macOS

[GIF: double-tap fn, speak a sentence, watch it land in the active editor — no spinner, no network indicator]

Murmur is a Mac dictation app that runs whisper.cpp on-device. Double-tap fn, dictate, release — the text is pasted into whatever app has focus. Zero network during transcription.

Not trying to be Wispr Flow. Wispr is excellent at what it does; it's also a cloud service with an account and a subscription. Murmur is the local-first alternative for people who don't want their microphone audio crossing the network — writers drafting in iA Writer or Ulysses, engineers dictating commit messages in a terminal, anyone working in a regulated environment.

What's in 1.0:
- Double-tap fn to dictate, release to paste. Configurable.
- whisper.cpp transcription, on-device. Pick your model (tiny 75 MB through large-v3 2.9 GB).
- Editable vocabulary list for names, acronyms, product terms.
- Cleanup profiles: Raw, Casual, Formal, Code (Code preserves identifiers and skips sentence-casing).
- Opt-in history viewer with one-click re-copy. Disabled by default.
- Settings UI with seven tabs. Sparkle in-app updates.
- macOS 13+, Apple Silicon and Intel. Free, MIT.

Install: `brew install --cask murmur` or DMG at https://murmur-landing-phi.vercel.app/
Source: https://github.com/roshanshah11/murmur

Genuinely want feedback — issues, PRs, "this is worse than X at Y" reports all welcome.
