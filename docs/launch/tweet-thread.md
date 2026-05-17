# Murmur 1.0 tweet thread

**1/**
Shipping Murmur 1.0 today — a local-first dictation app for macOS. Double-tap fn, talk, paste. whisper.cpp runs on your machine. No account, no cloud, no subscription. Free + MIT.

[screenshot: notch overlay during a dictation, with the paste happening into a text editor behind it]

**2/**
The local-first claim, plainly: zero network calls during transcription. Full stop. Sparkle checks for app updates and the model downloader pulls weights on first launch. That's it. Your microphone audio never leaves the machine.

**3/**
What 1.0 actually ships with:
- editable vocabulary (for names whisper keeps mangling)
- four cleanup profiles (Raw / Casual / Formal / Code — Code preserves identifiers)
- whisper model picker (tiny 75 MB through large-v3 2.9 GB)
- opt-in history viewer, off by default

**4/**
Honest tradeoff vs cloud apps like Wispr Flow: they're a few points more accurate on noisy audio and offer real-time partial transcripts. Murmur doesn't. It gives you the final text on key release, on-device, in well under a second on Apple Silicon. Different deal.

**5/**
`brew install --cask murmur` — or grab the DMG and the source at:

https://github.com/roshanshah11/murmur
https://murmur-landing-phi.vercel.app/

Would love your feedback, especially the parts where it falls down.
