# Murmur — 20 Consumer User Scenarios

Verification matrix candidates for v1.0. Each scenario is a concrete person in a concrete situation designed to surface a specific failure mode.

---

## 1. Maya — Novelist drafting in Scrivener

1. **Persona**: Literary novelist, mid-career, lifelong Mac user, low patience for tech friction.
2. **Trigger**: Hand cramps after 4 hours of editing; wants to dictate the next 600 words of a chapter rather than type them.
3. **Flow**:
   - Opens Scrivener, places cursor in the document body editor pane.
   - Double-taps `fn`, talks for ~6 minutes including pauses for thought, uses "comma," "period," and "new paragraph" verbally.
   - Stops with `fn`, expects Formal profile to insert clean paragraphs.
   - Vocabulary: character names "Elowen", "Cassiopeia", place name "Vintersmoor".
   - Language: English.
4. **Success criterion**: One ~600-word block lands at cursor in Scrivener with paragraph breaks honored and proper-noun vocabulary spelled correctly.
5. **Most likely failure mode**: Long recording exceeds whisper.cpp's chunking, paste arrives truncated or with "new paragraph" left as literal text instead of `\n\n`.
6. **What we should test**: Record a 6-minute fixture, assert paste length within 5% of ground truth and that "new paragraph" tokens were converted to actual newlines.

---

## 2. Devraj — Senior backend engineer in Cursor

1. **Persona**: Staff engineer, 15 years experience, types fast, skeptical of dictation.
2. **Trigger**: Wants to write a long PR description in Cursor's commit-message panel without breaking flow from terminal.
3. **Flow**:
   - Cursor focus, commit message multiline input field.
   - Profile: Code (preserves operators, leaves identifiers alone).
   - Says: "Refactor the auth middleware to short circuit when the JWT exp claim is null, return 401 with code `AUTH_EXP_MISSING`, and add a unit test covering the null path."
   - Vocabulary: "JWT", "JSON", "OAuth", "Postgres", `AUTH_EXP_MISSING`.
4. **Success criterion**: Identifier `AUTH_EXP_MISSING` survives verbatim in caps with underscores; "401" is numeric; no spurious period after "JWT".
5. **Most likely failure mode**: Cleanup profile lowercases or hyphenates the constant, or whisper transcribes "401" as "four oh one".
6. **What we should test**: Code profile preserves `[A-Z_]{4,}` tokens from vocabulary and converts spoken digit strings to numerals.

---

## 3. Priya — Litigation associate in Microsoft Word

1. **Persona**: 2nd-year BigLaw associate, billable-hour pressure, dictates between meetings.
2. **Trigger**: Drafting a paragraph for a motion to dismiss, needs precise legal phrasing.
3. **Flow**:
   - Word for Mac, cursor inside a numbered list item.
   - Profile: Formal.
   - Speaks 90 seconds of legalese: "Plaintiff's claim fails as a matter of law under Rule 12(b)(6) because…"
   - Vocabulary: "Rule 12(b)(6)", "Iqbal", "Twombly", "in pari delicto", "res judicata".
4. **Success criterion**: Latin terms italicized-ready (correctly spelled), citation `12(b)(6)` preserved with parens, paste does not break Word's numbered list formatting.
5. **Most likely failure mode**: Paste action via CGEvent strips rich-text context and resets list numbering, or whisper outputs "twelve b six" instead of "12(b)(6)".
6. **What we should test**: Vocabulary substitution rules can encode literal punctuation like `12(b)(6)`, and paste uses a method that doesn't disturb the host app's list state.

---

## 4. Dr. Owen — ER physician on shift

1. **Persona**: Emergency-medicine attending, dictates between patients on a hospital MacBook.
2. **Trigger**: Needs to drop a quick clinical note into Epic's web client running in Safari.
3. **Flow**:
   - Safari, Epic Hyperspace web text field focused.
   - Profile: Casual (he'll edit later).
   - Says: "62-year-old male, chief complaint chest pain, troponin negative times two, EKG normal sinus, dispo home with cardiology follow-up."
   - Vocabulary: "troponin", "EKG", "dispo", "PRN", drug names "metoprolol", "atorvastatin".
4. **Success criterion**: Medical terms render correctly; "62-year-old" hyphenates; "times two" becomes "x2" or stays as words consistently with a known rule.
5. **Most likely failure mode**: Spotify auto-pause logic interferes with Epic's hotkey listeners, or vocabulary file gets too large and lookup slows the cleanup step past 2s.
6. **What we should test**: Vocabulary list of 200+ medical entries still cleans in <500ms; Safari paste lands in the focused field reliably.

---

## 5. Jordan — CS undergrad studying with AirPods

1. **Persona**: 19, sophomore, uses AirPods Pro 2 with mic for everything.
2. **Trigger**: Walking between classes, wants to capture a thought into Apple Notes.
3. **Flow**:
   - AirPods are the default input; iPhone is NOT involved — Mac is the recording device on the lid-closed clamshell setup back at his desk? No — laptop is open in his backpack pocket… actually he stops on a bench, opens lid, taps `fn`.
   - Apple Notes focused.
   - Profile: Casual.
   - Says: "Idea for OS final project: build a tiny scheduler that uses CFS but adds a fairness boost for IO bound threads."
4. **Success criterion**: AirPods mic is selected, not the built-in mic that's currently muffled by the lid; transcription captures "CFS" and "IO bound".
5. **Most likely failure mode**: AVAudioEngine picks built-in mic because AirPods aren't promoted to default input quickly enough; result is unusable.
6. **What we should test**: Murmur reads the *current* `AVAudioSession` input at start-of-recording, not at app launch; explicit AirPods-routing fixture.

---

## 6. Sasha — Indie founder in Slack

1. **Persona**: Solo founder, 30s, Slack-native, types in 5 channels at once.
2. **Trigger**: Wants to dictate a 3-sentence reply in #eng instead of typing.
3. **Flow**:
   - Slack desktop, channel composer focused, two emoji autocompletes pending.
   - Profile: Casual.
   - Says: "Hey team, pushed the fix for the onboarding 500. Let's monitor Sentry for the next hour. Thumbs up if good."
   - Vocabulary: "Sentry", "Datadog", "PostHog".
4. **Success criterion**: Paste appears in Slack composer without dismissing emoji autocomplete; "Thumbs up" optionally becomes `:thumbsup:`? Actually no — we just want the literal words.
5. **Most likely failure mode**: Slack's Electron text-input quirks reject paste-via-keystroke and the text never lands; user sees nothing happen.
6. **What we should test**: Slack composer paste end-to-end with an integration fixture; verify pasteboard fallback path triggers on insertion failure.

---

## 7. Hana — UX researcher transcribing into Notion

1. **Persona**: Senior researcher, dictates verbatim quotes from interview notes.
2. **Trigger**: Wants to log a participant insight while it's fresh.
3. **Flow**:
   - Notion desktop, inside a toggle block on a research page.
   - Profile: Raw (she wants disfluencies preserved for the quote).
   - Says: "Um, I guess what I really want is, like, for the app to just remember where I was last time, you know?"
4. **Success criterion**: "Um", "like", "you know" all preserved; no auto-cleanup.
5. **Most likely failure mode**: Raw profile silently runs the disfluency-removal regex anyway; or Notion's toggle block eats the paste and dumps text into the parent.
6. **What we should test**: Raw profile is a strict pass-through (assert string equality with whisper raw output) and Notion toggle-block paste lands inside the toggle.

---

## 8. Tomás — Spanish-speaking marketer dictating in Spanish

1. **Persona**: Mexico City-based growth marketer, native Spanish, English-fluent.
2. **Trigger**: Drafting a LinkedIn post in Spanish.
3. **Flow**:
   - Chrome → LinkedIn post composer.
   - Language setting: `es`.
   - Profile: Formal.
   - Says: "Hoy lanzamos la nueva campaña de retención. Estoy muy orgulloso del equipo. Pueden ver los resultados preliminares en el dashboard."
   - Vocabulary: brand name "Talento+", "OKR".
4. **Success criterion**: Accents preserved (`campaña`, `orgulloso`), punctuation Spanish-style, brand "Talento+" survives with the plus sign.
5. **Most likely failure mode**: Whisper model loaded is English-only (the default `small.en`); transliterates everything as garbled English.
6. **What we should test**: When user language is non-English, app refuses to use `.en` models and either downloads or warns; vocabulary `+` character survives cleanup.

---

## 9. Akira — Japanese ESL speaker in Gmail

1. **Persona**: Software PM, Japanese native, conversational English with strong accent.
2. **Trigger**: Replying to a customer escalation email in Gmail.
3. **Flow**:
   - Safari → Gmail compose window.
   - Language: English.
   - Profile: Formal.
   - Says: "Thank you for reaching out. We have identified the root cause of the latency issue and a fix will ship by Friday."
4. **Success criterion**: Accent doesn't degrade transcription beyond ~5% WER on common business English.
5. **Most likely failure mode**: Small whisper model maps "latency" to "latency-ish" garble; or "Friday" lowercased.
6. **What we should test**: Accented-English fixture set passes a defined WER threshold; weekday capitalization is enforced in Formal profile.

---

## 10. Riley — Disabled writer using switch control

1. **Persona**: Writer with RSI, primary input is voice + a single mechanical foot switch mapped to `fn` double-tap.
2. **Trigger**: Lengthy email reply, can't use the keyboard.
3. **Flow**:
   - Apple Mail compose.
   - Foot switch sends two rapid `fn` keystrokes.
   - Profile: Casual.
   - Speaks 4 minutes total in 3 segments with foot-switch pauses between them (start, stop, start, stop, start, stop).
4. **Success criterion**: All three segments land sequentially in the email body without losing focus between segments.
5. **Most likely failure mode**: Second double-tap arrives during the paste step and gets swallowed, leaving the recorder in an inconsistent state.
6. **What we should test**: Recorder state machine is idempotent across rapid start/stop cycles; no segment loss with <500ms gap.

---

## 11. Casey — Designer in Figma

1. **Persona**: Product designer, dictates notes onto Figma sticky notes during async review.
2. **Trigger**: Wants to leave 8 short stickies on a flow without typing each.
3. **Flow**:
   - Figma desktop app, sticky note in edit mode.
   - Profile: Casual.
   - Says one sticky's worth: "Spacing here feels cramped, bump to 16 px."
   - Repeats 8 times, moving to a new sticky between recordings.
4. **Success criterion**: Each short utterance pastes into the currently selected sticky; "16 px" stays as "16 px" not "sixteen pixels".
5. **Most likely failure mode**: Whisper's VAD treats the 1-sec utterance as too short and returns empty; user gets nothing 8 times in a row.
6. **What we should test**: Minimum-length utterance (<1.5s) still produces output if speech detected; numeric-units cleanup rule.

---

## 12. Eun-ji — Journalist on a coffee-shop network

1. **Persona**: Investigative reporter, dictating a sensitive paragraph in public.
2. **Trigger**: Wants to capture a source's paraphrased quote before forgetting it.
3. **Flow**:
   - Obsidian, daily note open.
   - Profile: Raw.
   - Coffee shop has espresso machine, conversations, music at ~70 dB.
   - Says quietly: "Source claims the contract was signed before the audit was completed."
4. **Success criterion**: Transcription is legible despite noise; nothing leaves the machine (offline assertion).
5. **Most likely failure mode**: Whisper hallucinates extra phrases from background music ("[Music]" tokens left in output), or user discovers a stray telemetry call.
6. **What we should test**: Network-egress integration test confirms zero outbound connections during a full record→transcribe→paste cycle; `[Music]`/`[Applause]` whisper artifacts are stripped.

---

## 13. Marcus — High-school teacher grading in Google Docs

1. **Persona**: 10th-grade English teacher, grades 90 essays a weekend, wants voice comments.
2. **Trigger**: Leaving a margin comment on an essay.
3. **Flow**:
   - Chrome → Google Docs → right-click → comment.
   - Comment box focused.
   - Profile: Casual.
   - Says: "Your thesis is strong, but paragraph 3 needs a concrete example. See chapter 7 of the textbook."
4. **Success criterion**: Comment box receives paste; numbers "3" and "7" numeric; doesn't trigger Docs' "/" command palette accidentally.
5. **Most likely failure mode**: Paste includes a stray newline that submits the comment prematurely.
6. **What we should test**: Final paste payload contains no trailing newline unless the user said "new paragraph" at the end.

---

## 14. Lena — German PhD researcher mixing English + German

1. **Persona**: ML researcher, code-switches between German and English mid-sentence.
2. **Trigger**: Writing a methods note in Bear.
3. **Flow**:
   - Bear note focused.
   - Language: auto (or German with English fallback).
   - Says: "Die Genauigkeit lag bei 87.3 percent — das ist besser als baseline, aber wir brauchen mehr Daten."
4. **Success criterion**: German umlauts preserved (`Genauigkeit`), English technical words ("baseline") not mangled, decimal "87.3" preserved.
5. **Most likely failure mode**: Auto-detect locks to one language and breaks the other half; decimal becomes "87 point 3".
6. **What we should test**: Mixed-language fixture; decimal numbers preserved in numeric form by Formal/Casual profiles.

---

## 15. Yusuf — Returning user after a macOS update

1. **Persona**: Casual user, uses Murmur 2x a week, just installed macOS 14.5.
2. **Trigger**: First dictation after the OS update.
3. **Flow**:
   - Hits `fn`-`fn` like always.
   - Nothing happens because macOS reset Accessibility permission silently.
4. **Success criterion**: Murmur detects missing permission within 200ms, surfaces an actionable banner pointing to System Settings, doesn't silently fail.
5. **Most likely failure mode**: App proceeds as if recording, captures audio, then crashes at paste-via-CGEvent step with no user-facing explanation.
6. **What we should test**: Pre-flight permission check on every recording start; user-facing error path when CGEvent posting is denied.

---

## 16. Tabitha — Brand-new user 90 seconds after install

1. **Persona**: First-time user, downloaded Murmur from a tweet, hasn't read docs.
2. **Trigger**: Curiosity — "let me see if this thing works."
3. **Flow**:
   - Drags to Applications, launches.
   - Sees menubar icon, doesn't know about `fn` double-tap.
   - Tries clicking the icon, sees a menu, sees "Start recording" maybe?
   - Tries `fn` once, nothing. Tries holding it. Eventually double-taps.
   - Speaks a test sentence into TextEdit.
4. **Success criterion**: Within 90 seconds of launch, the user has dictated one successful sentence with zero documentation.
5. **Most likely failure mode**: Microphone permission prompt arrives mid-recording and the first attempt produces silence; user concludes app is broken and quits.
6. **What we should test**: Onboarding requests mic + accessibility permissions on first launch, before the first `fn` double-tap; menubar icon includes a "Try a test recording" item.

---

## 17. Felix — User who screwed up vocabulary config

1. **Persona**: Power user, 6 months of usage, recently bulk-imported 400 vocabulary entries from a CSV.
2. **Trigger**: Normal dictation into iMessage.
3. **Flow**:
   - iMessage to spouse: "Picking up groceries on my way home, anything you need?"
   - Vocabulary file has a typo'd entry: `"home" → "home,"` (trailing comma).
4. **Success criterion**: Either the bad entry is rejected at import time, or the user can edit/disable it without crashing.
5. **Most likely failure mode**: Recursive substitution loop or silent corruption every time the word "home" appears.
6. **What we should test**: Vocabulary import validator rejects entries whose replacement contains the source as a substring; runtime substitution has a max-iterations guard.

---

## 18. Aanya — Rapid-fire founder dictating into ChatGPT

1. **Persona**: AI startup founder, dictates prompts to ChatGPT 50 times a day.
2. **Trigger**: Writing a long prompt with code embedded.
3. **Flow**:
   - Chrome → chat.openai.com, focused on the textarea.
   - Profile: Code.
   - Says: "Write a Python function called `parse_invoice` that takes a string and returns a dict with keys `total`, `tax`, and `line_items`. Use regex, not LLM."
   - Vocabulary: `parse_invoice`, "regex".
4. **Success criterion**: Identifiers and backticks render correctly; "regex" lowercase; ChatGPT's textarea isn't navigated away from by accidental Enter.
5. **Most likely failure mode**: Whisper transcribes `parse_invoice` as "parse invoice" (with space) and Code profile can't recover it without a vocabulary hit.
6. **What we should test**: Code profile snake_case rule: if a vocabulary entry exists for a snake_case identifier, multi-word transcriptions of it are joined.

---

## 19. Hiroko — User on an Intel MacBook Pro 2018

1. **Persona**: Long-tail user on old hardware, no Apple Silicon.
2. **Trigger**: Wants to dictate a Linear ticket description.
3. **Flow**:
   - Linear web app, ticket description field.
   - Profile: Casual.
   - Selects `small` whisper model in settings.
   - Speaks 30 seconds.
4. **Success criterion**: Transcription completes in <15 seconds (acceptable on Intel); CPU doesn't peg to 100% and freeze the machine.
5. **Most likely failure mode**: Murmur ships an Apple Silicon-only whisper.cpp binary or coreml-only path; Intel users get instant crash or 5-minute hang.
6. **What we should test**: Universal2 binary actually runs whisper.cpp on x86_64; perf budget asserted on an Intel CI runner or fixture.

---

## 20. Sam — History-viewer user trying to find an old dictation

1. **Persona**: Murmur user for 3 weeks; remembers dictating something about a "Q3 hiring plan" last week but can't find where they pasted it.
2. **Trigger**: Opens the optional history viewer.
3. **Flow**:
   - Menubar → History.
   - Types "Q3 hiring" into the search field.
   - Expects to see the entry, with timestamp and target-app name.
   - Wants to copy it back to clipboard.
4. **Success criterion**: Full-text search returns the right entry in <300ms; "Copy" button copies the original cleaned text.
5. **Most likely failure mode**: History DB stores only the last 100 entries with no search, or stores raw whisper output instead of the cleaned text the user actually pasted.
6. **What we should test**: History persists (a) raw + cleaned versions, (b) timestamp, (c) frontmost-app bundle ID; full-text search is indexed and bounded in latency.

---

# Top 8 scenarios for v1.0 verification matrix

Picked for diversity across **app surface**, **profile**, **language**, **lifecycle moment**, and **failure class**. Each catches a distinct bug family — none are minor variants of another.

1. **#2 Devraj — Code profile in Cursor.** Covers identifier preservation, numeric handling, the Code cleanup profile, and a heavy-user developer flow. Catches: cleanup-profile regressions, vocabulary case-sensitivity.

2. **#3 Priya — Formal profile in Word with legal citations.** Covers the Formal profile, literal-punctuation vocabulary, and a native Mac app with rich-text quirks. Catches: paste-method side effects on host formatting.

3. **#5 Jordan — AirPods routing.** Covers audio-input device selection at runtime, not at launch. Catches: a silent failure class that ruins the user's first real-world mobile use.

4. **#8 Tomás — Non-English (Spanish) language path.** Covers the multi-language code path, model selection (rejecting `.en` models), and accented characters. Catches: the entire i18n surface in one test.

5. **#12 Eun-ji — Offline assertion + noise handling.** Covers the local-first promise (network-egress test) and whisper artifact stripping. Catches: trust-violating regressions and noisy-environment quality.

6. **#15 Yusuf — Returning user after macOS update.** Covers permission-loss detection and graceful failure. Catches: the most common real-world support ticket — "it just stopped working."

7. **#16 Tabitha — First-launch onboarding.** Covers the cold-start user journey, permission prompts, and discoverability. Catches: the install-to-first-success funnel that decides adoption.

8. **#20 Sam — History viewer search + copy-back.** Covers the optional history surface end-to-end: persistence, search, what-gets-stored. Catches: data-model regressions that only show up after days of use.

**What this set covers as a portfolio**:
- 4 cleanup profiles (Code #2, Formal #3, Casual #5/#15/#16, Raw indirectly via #12)
- 2 languages (English + Spanish)
- 6 distinct host apps (Cursor, Word, Apple Notes, Safari/web, TextEdit, History UI)
- 3 lifecycle stages (first launch, returning post-update, daily power user)
- 4 failure classes (transcription quality, paste/host-app integration, permissions/lifecycle, privacy/offline)

**What's deliberately left out of the gating set** (still valuable as Tier-2 regression tests): the ESL/accent quality bar (#9), the disability/rapid-cycle state-machine test (#10), the vocabulary-config-corruption guard (#17), and the Intel-hardware perf budget (#19). All four are critical for v1.0 sign-off but are better as nightly regression rather than per-PR gating because they need either curated audio fixtures or non-Apple-Silicon hardware.
