# Privacy

Murmur is built so this document can be short and specific. Nothing below is aspirational — it describes what the app actually does on your Mac today.

## What Murmur is and isn't

Murmur is a local-first dictation app. It runs entirely on your Mac. There is no cloud component, no account, and no telemetry. Audio and transcripts never leave the device through Murmur.

## Permissions Murmur requests

- **Microphone** — to capture audio during an active recording session. Murmur opens the mic only while you are explicitly recording.
- **Accessibility** — to insert transcribed text into the app you are using and to read the global hotkey.
- **Apple Events (Automation)** — to pause and resume Spotify or Apple Music while you dictate. You can decline this and dictation still works.

## Data Murmur creates on the Mac

- `~/Library/Application Support/Murmur/` — settings, vocabulary, prompts, downloaded Whisper models, and (if enabled) the History database.
- `~/Library/Logs/Murmur/` — diagnostic logs. Logs record event types, durations, error codes, and model identifiers. Logs never contain transcript text or audio.
- `~/Library/Caches/Murmur/` — short-lived audio chunks during an active recording, deleted as soon as transcription completes.

## What Murmur never does

- Murmur never makes a network request in the audio or transcription path.
- Murmur never writes transcript text to logs.
- Murmur never retains the source audio after a successful transcription. The temporary file in `Caches/` is deleted on success and on app quit.
- Murmur never holds the microphone open outside an active recording session.

## Retention

Every piece of stored data is user-controllable.

- **History** is opt-in. It is off by default. When off, Murmur writes nothing about your transcripts to disk after they are pasted.
- **Vocabulary, prompts, and settings** persist until you change or delete them.
- **Downloaded models** persist until you remove them from the Models tab.

## How to delete everything

In the app: Settings → General → **Reset Murmur**. This removes all Murmur data and quits the app.

From a terminal:

```bash
rm -rf ~/Library/Application\ Support/Murmur ~/Library/Logs/Murmur ~/Library/Caches/Murmur ~/Library/Preferences/com.murmur.app.plist
```

## Third parties

Three external components are involved. None of them carry your audio or transcripts off the Mac.

- **whisper.cpp** — bundled and run as a local subprocess. It does not make network calls.
- **Sparkle** — the update framework. Sparkle reaches `https://roshanshah11.github.io/murmur/appcast.xml` only when checking for updates. It sends the user agent and current app version. No personal data.
- **Apple Events to Spotify and Apple Music** — local AppleScript-style events to pause playback during recording. No data leaves the machine.

## Updates

Sparkle fetches `appcast.xml` only when an update check runs (automatically on a configurable interval, or manually from Settings → Updates). That fetch is the only outbound request Murmur ever makes. Update artifacts (the signed DMG) are downloaded from GitHub Releases.

## Compliance posture

No personal data leaves the device. Murmur does not act as a data controller or processor under GDPR or CCPA — there is no Murmur-operated service that receives user data. You retain full control of the data Murmur creates on your Mac.

## Contact

Questions, corrections, or concerns: `ashah@alixpartners.com`.
