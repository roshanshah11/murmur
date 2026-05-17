# Murmur — double-tap fn, speak, paste. Whisper runs on your Mac, not in the cloud.

Murmur is a macOS dictation app I built because the current options felt like a forced choice: Apple's stock dictation, which is fine but forgets what you're working on the moment you switch apps, or cloud apps like Wispr Flow, which are sharper but stream your microphone audio to a server you don't own. I wanted something in the middle — fast, opinionated, and entirely local. Double-tap the fn key, talk, release. The transcript is pasted into whatever app has focus. That's it. No account, no telemetry, no network calls during transcription. Full stop.

The honest tradeoffs: whisper.cpp running on-device is a few percentage points behind the best cloud STT on noisy audio and unusual proper nouns. There's no real-time partial transcript — you get the final text on release, not a streaming preview. The default whisper model is 142 MB and downloads on first launch; the large-v3 model is 2.9 GB if you want maximum accuracy. On Apple Silicon, the small model transcribes a 10-second clip in well under a second. On Intel Macs it's slower but usable. I think those are fair trades for "your voice never leaves the machine."

A few things I made sure to ship in v1: an editable vocabulary list (for names, acronyms, product terms whisper consistently mangles), cleanup profiles (Raw, Casual, Formal, Code — the last one preserves identifiers and skips sentence-casing), a model picker, an opt-in history viewer so you can re-copy past transcripts, and Sparkle for in-app updates. macOS 13+, Apple Silicon and Intel. Free, MIT licensed.

Install: `brew install --cask murmur` or grab the DMG from the site. Would genuinely love feedback — what's broken, what's missing, where it falls down vs the cloud apps you've tried.

Repo: https://github.com/roshanshah11/murmur
Site: https://murmur-landing-phi.vercel.app/
