# Building Murmur, a local-first dictation app for the Mac

I dictate a lot. Drafts, commit messages, Slack replies I'm too tired to type, half of this post. For about a year I lived inside Apple's stock dictation, then I tried a couple of the cloud apps everyone recommends, and ended up uncomfortable with both. So I built the thing I actually wanted. It's called Murmur, it's free and MIT-licensed, and v1.0 ships today.

## The itch

There are basically two camps on macOS right now. Apple's built-in dictation is private and free, but it's also context-blind in a way that gets old fast — it doesn't know what app I'm in, it forgets my vocabulary the moment I close a doc, and the cleanup is "punctuation as literally spelled." It's good enough for a one-line text. It is not good enough for a paragraph of prose, much less a paragraph of prose with three proper nouns in it.

The cloud apps — Wispr Flow is the standard-bearer, and it really is sharp — solve the accuracy problem by streaming your microphone audio to a server, transcribing it there, and sending the text back. That's a reasonable engineering choice. It's also a thing I personally don't want happening while I'm dictating about a client engagement, an unannounced product, or my own medical stuff. The latency is excellent and the accuracy is real, but the deal is: your voice leaves the machine.

I wanted the middle option. Fast enough to feel like Wispr. Local like Apple. Opinionated like neither.

## The build

Murmur is whisper.cpp behind a Swift app. The core loop is small: register a global hotkey (double-tap fn by default), capture audio from the default input device, hand the buffer to a whisper.cpp context running in-process, run the result through a cleanup pass, paste it into whatever app has focus. There's no server. There's no account. There's no telemetry, opt-in or otherwise — I didn't write the telemetry code in the first place, which is the only way to be sure.

A few opinions I committed to early and don't regret:

**Local-only, always.** The transcription pipeline has zero network calls. Sparkle reaches out to check for app updates and the model downloader pulls weights from Hugging Face on first run. Those are it, and both are gated behind explicit user action.

**Opt-in history.** A lot of dictation apps quietly log your transcripts so you can re-copy them later. Useful! Also a privacy surface. Murmur's history viewer exists but ships disabled; you turn it on in Settings if you want it, and it's a flat SQLite file you can nuke at any time.

**Cleanup as profiles, not magic.** Whisper's raw output is decent prose but bad for code (lowercases identifiers, inserts spaces in `camelCase`, "helpful" punctuation in URLs). Instead of one global cleanup, Murmur has four profiles — Raw, Casual, Formal, Code — and you pick per-session with a keyboard shortcut. Code is the one I use most. It's the difference between "I dictated my git commit" and "I dictated my git commit and then spent two minutes un-fixing whisper's fixes."

**Vocabulary is editable, not learned.** Whisper consistently mangles certain names (mine, my partner's, every coworker named anything other than "Mike"). I'm not going to ship a system that quietly fine-tunes on your speech in the background — partly because that's a privacy concern in disguise, partly because it's hard to get right. Instead there's a plain-text vocabulary list. You add the words it gets wrong, it stops getting them wrong.

**Model picker, not magic auto-selection.** Murmur ships with whisper-small (142 MB) as the default because it's the best accuracy-per-millisecond on the Macs I tested. If you want large-v3 (2.9 GB), it's two clicks. If you want tiny (75 MB) because you're on an old Intel MacBook Air and you just need rough notes, that's two clicks too. The picker tells you the file size and the rough relative accuracy. No surprises.

## What's next

A few things I deliberately didn't ship in 1.0 and want to revisit:

- **Hold-to-talk.** Double-tap fn is great for sentences, mildly annoying for one-word corrections. Hold-fn-to-talk is queued for 1.1.
- **Background model updates.** Right now you pick a model and download it manually. I'd like the app to notice when a better quantization ships and offer the swap.
- **Local LLM cleanup.** The cleanup profiles in 1.0 are deterministic — regex, a small ruleset, and good defaults. A 3B-class local model could do meaningfully better cleanup ("rewrite this as a formal email" without going to the cloud). I want to ship this carefully because the moment you involve an LLM the failure mode becomes "confidently rewrites the wrong thing." 2.0 territory.

If you try Murmur and it falls down, please tell me. The repo is at github.com/roshanshah11/murmur and there's a sponsor button there if you want to throw a few dollars at hosting the model mirror. Otherwise — install with `brew install --cask murmur` or grab the DMG at murmur-landing-phi.vercel.app. I'd love to know what you think.
