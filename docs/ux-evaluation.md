# Murmur UX Evaluation — Eloquent as a reference

**Date:** 2026-06-06
**Author:** UI/UX review pass
**Scope:** UI surfaces only — menubar dropdown, live dictation indicator, settings panels,
onboarding, empty/error/permission states, microcopy, theming, motion. **Not** in scope:
transcription engine, the state machine's transcription hot path, paste mechanics, or in‑flight
Parakeet feature work (only their settings/states are surfaced).

## What this document is

This is a **decision record**, not a redesign brief. Eloquent (Google AI Edge Eloquent, a
12B‑LLM dictation app, `com.google.AIEdgeEloquent`, v1.5.0, Flutter) was mined surface‑by‑surface
and judged **against Murmur's existing implementation**. For each surface the verdict is one of:

- **KEEP MURMUR** — Murmur's is as good or better; do not change.
- **ADAPT** — Eloquent's approach (or a shared principle) is genuinely better for Murmur's
  users; adopt the *idea*, rewritten in Murmur's voice and visual language.
- **ADD** — a state/surface Murmur lacks and should have.
- **N/A — LLM** — the surface exists only to support Eloquent's large‑language‑model features.
  Murmur has **no LLM features and wants none**; these are explicitly *not* adopted.

**Murmur's minimalist, quiet, deterministic, no‑LLM identity is treated as a strength to protect,
not a deficiency to fix.** A verdict of KEEP across most surfaces is the expected outcome, and is
what happened: **22 KEEP, 3 ADAPT, 1 ADD, 8 N/A‑LLM.**

## Evidence sources

- **Eloquent (bundle‑based):** `plutil` on `Info.plist`/`GoogleService-Info.plist`;
  `assetutil --info Assets.car` (vector glyph + image asset names); `ls -R` of
  `eloquent_prod.assets`; `strings` on `Contents/MacOS/Eloquent` (Dart AOT snapshot — Eloquent's
  copy lives as ~1322 localization‑key getters + widget class names, all ASCII, runtime‑localized;
  there are no `.strings` files beyond the generic Flutter `Base.lproj/MainMenu.nib`).
- **Murmur (source‑based):** full read of `NotchIndicator.swift`, `SpectrumBarsView.swift`,
  `main.swift` (menubar + status item), `Notifier.swift`, `UI/Onboarding/*`, all seven
  `UI/Settings/*` tabs, `UI/History/HistoryWindow.swift`.
- Where a verdict rests on a design principle rather than the bundle, it is marked
  **(principle)**. Where the bundle directly motivates it, **(bundle)**.

---

## 1. Menubar dropdown + status‑bar item

| Surface | Eloquent | Murmur today | Verdict | Reasoning | Source |
|---|---|---|---|---|---|
| **Menubar menu contents** | Minimal `NSStatusItem` menu: *Toggle overlay*, *Settings*, *Quit Eloquent* (it also keeps a Dock icon). | 14+ items, including three permanently **disabled status rows** (`Raw Transcript Mode: On/Off`, `Debug Retain Audio: On/Off`, `Trigger: double-tap fn`) and three developer/diagnostic actions (`Test Setup`, `Open Config`, `Open Logs Folder`) sitting at the top level next to user actions. | **ADAPT** | Murmur's own ethos is "quiet, no clutter," and its consumer positioning makes a dev‑flavored top‑level menu off‑identity. Eloquent's restraint is the inspiration, **not** the spec (3 items would hide useful troubleshooting for a local app). Fix: move the two debug status rows + the three diagnostic actions into a single **Diagnostics ▸** submenu; keep every function; keep the `Trigger: double-tap fn` hint at top level because the menubar is the *only* persistent discoverability surface for a windowless app. | principle + bundle |
| **Status‑bar indicator** | Real **status‑bar icon** (`statusBarIconAccessibilityLabel` = "Eloquent Status Bar Icon"). | Bare **text word** `"Murmur"` when idle; `● 0:05` / `… 0:03` while active. A literal word in the menu bar is not idiomatic macOS. | **ADAPT** | A glyph is more native and reinforces Murmur's existing brand mark (the `waveform` symbol already used in onboarding + About). Use the `waveform` SF Symbol idle, a red `mic.fill` while recording, `waveform` while transcribing, `arrow.down.circle` while downloading — keeping the compact elapsed‑timer / percent text alongside. Must carry an `accessibilityDescription` so VoiceOver still says "Murmur" in the symbol‑only idle state, and the red tint must read in both light and dark menu bars. | bundle + principle |
| **Recent‑history submenu** | History is a full tab, not a menubar submenu. | `History ▸` shows last 10 transcripts with previews + *Open Full History File…* / *Clear History…*; empty state `(no transcriptions yet)`. | **KEEP** | Murmur's at‑a‑glance recents in the menubar is a genuinely nice touch for a windowless app and already has a clean empty state. | — |
| **Quit / Settings / Updates** | *Settings*, *Quit Eloquent*. | `Settings…` (⌘,), `Check for Updates…`, `Quit` (⌘Q), conditional `⚠ Grant Accessibility Permission`. | **KEEP** | Standard, keyboard‑shortcutted, and the conditional AX warning is better than Eloquent (which has no equivalent top‑level nudge). | — |

---

## 2. Live dictation indicator (NotchIndicator) + per‑state treatment

Eloquent's indicator is a **floating panel** (`FloatingPanel`/`FloatingPanelService`) toggled from
the status bar, with a "Show/Hide live transcript" toggle and "instant transcript" (skip polishing)
option. Murmur's is a **notch‑native pill** that slides from the camera notch, morphs width per
state, and drives `SpectrumBarsView`.

The task names a canonical state list — *idle / listening / transcribing / cleaning / inserting /
error*. Murmur's actual states map onto it as below.

| State (task vocabulary) | Eloquent treatment | Murmur state + treatment | Verdict | Reasoning | Source |
|---|---|---|---|---|---|
| **Overall indicator** | Floating panel, larger, with live‑transcript and polish options. | Notch pill; width morphs (`setFrame` spring, open 0.18s / morph 0.22s / close 0.14s); subviews crossfade (0.18s); concave top corners mate with the physical notch. | **KEEP** | Murmur's is more native, quieter, and more deterministic — a better fit than a floating LLM panel. | principle |
| **idle** | "Tap to speak" / "Speak now…" captions. | `.idle`: dimmed `mic` + `Double-tap fn` + faint dotted bars (`bars.mode = .idle`). | **KEEP** | Murmur already teaches the trigger in the idle pill; quieter than Eloquent. | — |
| **listening** | Recording captions + live transcript. | `.recording`: red `mic.fill` (pulsing), `REC`, live `SpectrumBarsView` (`.live`), monospaced elapsed timer, hover‑revealed *Stop*/*Cancel*, red glow. | **KEEP** | Richer than required and already reduce‑motion aware (pulse/glow suppressed). Murmur deliberately does **not** stream a live transcript — it pastes finished text. That is a design choice, not a gap. | — |
| **transcribing** | Server/on‑device ASR with fallbacks. | `.processing(label:)`: `waveform` icon, `Transcribing…`, bars `.processing` wave, timer continues. | **KEEP** | Clear and deterministic. | — |
| **cleaning** | A distinct **LLM "polishing"** step (`onDevicePolisherType`/`serverPolisherType`, "polishing"). | **No such state** — Murmur's text cleanup is deterministic profiles applied instantly inside the transcribe step. | **N/A — LLM** | Eloquent's "cleaning/polishing" indicator exists only because an LLM rewrites the transcript. Murmur's cleanup is regex/profile‑based and instantaneous; adding a "cleaning" indicator would invent latency that doesn't exist and imply an LLM step that doesn't exist. Correctly absent. | bundle |
| **inserting** | "Calling insertText…", "Auto-copying to clipboard", "Insertion Failed. Copied to Clipboard". | `.pasting` → `.success(label:)`: green `checkmark.circle.fill` + contextual `Pasted into <App>` or `Copied to clipboard`, one‑shot success bounce, 1.6s auto‑dismiss. | **KEEP** | Murmur's *contextual* success ("Pasted into TextEdit") is more informative than Eloquent's generic strings, and the copied‑only fallback already matches Eloquent's best behavior. | — |
| **error** | "Eloquent can't hear you…", "…falling back…", generic "An error occurred, please try again." + `retry`. | `.error(label:)`: `exclamationmark.triangle.fill`, message, persistent **Retry** button (stays until retried or next state). | **KEEP** | Murmur already has the actionable Retry affordance Eloquent uses, in a quieter form. | — |
| **downloading** (model) | Dedicated download pages (§4). | `.downloading(progress:)`: `arrow.down.circle`, `Downloading model`, thin progress fill + `NN%`. | **KEEP** | Surfacing model‑download progress in the indicator itself is good and already present. | — |
| **appear / dismiss animation** | Compiled — exact curves unrecoverable; asset `floating.png` only. | Spring open/morph/close + alpha crossfade; success auto‑dismiss 1.6s; error sticky. | **KEEP** | No recoverable evidence Eloquent's motion is better; Murmur's is tuned and intentional. | bundle (no evidence) |
| **Reduce Motion (indicator)** | No evidence found. | Honored: mic pulse, success bounce, recording/success glow, and `SpectrumBarsView` all check `accessibilityDisplayShouldReduceMotion`. | **KEEP** | Murmur is already ahead here. | — |

---

## 3. Settings

| Surface | Eloquent | Murmur today | Verdict | Reasoning | Source |
|---|---|---|---|---|---|
| **Overall organization** | Top‑level tabs *Record / History / Dictionaries / Settings*, with Settings holding many groups (hotkeys, mic, text handling, **cloud toggle**, **model selection for Gemma**, history, **account**, legal). | Seven‑tab `TabView`: General, Recording, Vocabulary, Prompts, Models, Updates, About. | **KEEP** | Murmur's split is coherent and free of the account/cloud/Gemini groups that only exist for Eloquent's LLM+sign‑in model. No reorg needed. | principle |
| **General (history)** | History is its own tab + `saveDictationHistory` toggle. | `Enable dictation history` toggle (off by default), Open/Clear actions, explicit local‑path + "Nothing leaves your machine" footnotes. | **KEEP** | Murmur's privacy‑forward copy and off‑by‑default stance are stronger than Eloquent's. | — |
| **Recording tab** | Real hotkey customization (`hotkeysSectionTitle`, `dictationHotkeyLabel`). | **Stub:** `"Coming in a later phase."` | **KEEP (noted)** | Hotkey customization is **in‑flight feature work**, not UX polish, and touching it risks the hotkey path (out of scope). The honest stub is acceptable; building the feature is explicitly out of scope. Flagged for the roadmap, not changed. | bundle |
| **Vocabulary** | `Dictionaries` tab with custom dictionaries, **learn‑from‑edits**, and **Gmail‑mined terms**. | Deterministic find→replace vocabulary editor with live preview, import/export, reset, clean empty state (`No vocabulary yet`). | **KEEP** | Murmur's deterministic vocabulary is the no‑LLM equivalent and is already well‑built. Eloquent's learn‑from‑edits / Gmail mining are LLM‑adjacent (see §7). | bundle |
| **Prompts (cleanup profiles)** | Text **style transforms** (Formal/Shorten/Lengthen/Polish/Key‑points) — LLM rewrites. | Four deterministic profiles (Raw/Casual/Formal/Code) with live before→after preview. | **KEEP** | Murmur's profiles are deterministic cleanup, not LLM rewriting; the live preview is excellent. Do **not** adopt Eloquent's transform tabs (§7). | bundle |
| **Models — list & selection** | Two‑stage (base models + Gemma LLM), powered‑by‑Gemma branding, restart‑to‑apply dialog. | Engine picker (Parakeet/Whisper.cpp), curated model rows with size/language/recommended‑for metadata, language picker. | **KEEP** | Murmur's model UI is clear and free of LLM branding. | — |
| **Models — download progress UX** | `ProgressView`, then explicit **"Download Complete!"** / **"Download Failed"** toasts. | Per‑row `ProgressView` + `NN%`; on success a **green check + Use/Remove** (Whisper) or `Installed` (Parakeet); on failure red `Download failed:` footnote. **No completion confirmation** when the download was started from Settings and the user has navigated away. | **ADAPT (minimal)** | The inline green‑check state transition already *is* the completion confirmation for a user who is watching — Eloquent's exclamatory "Download Complete!" is exactly the louder voice the brief says to reject, so it is **not** copied. The one real gap is the Settings‑started download for a user who switched apps mid‑download: they get no signal. The in‑identity fix is a single **quiet `Notifier` notification** (Murmur's existing idiom, used for "History cleared", "Copied to clipboard"), **not** new inline UI and **not** a state‑machine change. Onboarding's download is left untouched (the user is watching; the green check + "Continue" enabling is immediate). | bundle + principle |
| **Updates** | Google Keystone, stable channel only; restart dialog. | `Update channel` (Stable; `Beta (coming soon)` disabled), auto‑check toggle, status line, "Check now", EdDSA/appcast explainer. | **KEEP** | Sparkle + the security explainer is appropriate and honest; the disabled Beta row is a low‑cost roadmap signal, not clutter worth a risky change. | — |
| **About** | Account/legal heavy. | Brand mark, version/build, GitHub/Docs/Sponsor links, **"Run setup again"** onboarding replay, "Made with ♥…" footer. | **KEEP** | Murmur's About is warmer and already provides the onboarding‑replay entry point the brief requires. | — |
| **Launch‑at‑login / appearance / theme settings** | None found. | None found (semantic colors → implicit dark mode). | **KEEP** | Neither app has these; not a gap created by the comparison. | bundle (no evidence) |

---

## 4. Onboarding

Eloquent: `Splash → Initializing → SignIn → EnableMacosPermissions → SelectMicrophone →
TestKeyboardShortcut → download` (with a rich animated keyboard‑shortcut tutorial: `keyboard.png`,
`swipe.gif`, `enable-keyboard-ios.mp4`).
Murmur: `welcome → howItWorks → microphone → accessibility → model → test → done`.

| Surface | Eloquent | Murmur today | Verdict | Reasoning | Source |
|---|---|---|---|---|---|
| **Step structure** | 6–7 steps incl. **Google sign‑in**. | 7 steps, **no sign‑in** (local‑only). Progress capsules with per‑step accessibility labels. | **KEEP** | Murmur's flow is complete and correctly omits the account step. | bundle |
| **Microphone rationale** | "This app needs microphone access to transcribe your speech." + denied recovery. | "Murmur needs the microphone to capture your voice. Audio stays local — it's transcribed on this Mac and discarded." + status pill (`Granted`/`Denied`/`Not granted`) + System Settings deep‑link. | **KEEP** | Murmur's rationale is more privacy‑specific; the status pill + deep‑link already matches Eloquent's recovery path. | — |
| **Accessibility rationale** | "Please grant accessibility permission to be able to insert dictated text…" + open‑settings. | "Accessibility lets Murmur paste transcribed text into the app you're using. It's also how the global double‑tap‑fn hotkey works." + live 0.5s AX polling that auto‑advances on grant. | **KEEP** | Murmur explains *both* uses (paste + hotkey) and auto‑advances on grant — better than Eloquent's manual step. | — |
| **Input Monitoring** | **No distinct prompt** (global key detection via `NSEvent` monitor + Carbon hotkey). | Not prompted (same technical reason). | **KEEP** | Correctly not surfaced — there is no separate permission to request. | bundle |
| **First/test‑dictation moment** | Keyboard‑shortcut test with animated media. | `test` step: prompt "Murmur is ready", live "What we heard" box, green "Heard you loud and clear." on match. | **KEEP** | Murmur's real end‑to‑end test (actual dictation, not just key‑press) is stronger. | — |
| **Persistence + replay** | "Marking onboarding as shown"; `finishOnboarding`. | `onboardingCompletedVersion` gate; replay via **About → Run setup again**. | **KEEP** | Already persisted and replayable, as the brief requires. | — |
| **Reduce Motion (onboarding)** | No evidence found. | **Not handled** — a 600 ms post‑grant "beat" before the accessibility step auto‑advances runs regardless of the system setting, and there was *no* `accessibilityReduceMotion` plumbing at all, unlike the indicator which honors it. (Steps already hard‑cut with no transition — so there is no existing onboarding *animation* to suppress.) | **ADD** | The brief explicitly requires Reduce‑Motion handling, and the indicator already honors it — a **consistency/accessibility fix**, not an Eloquent import. Added `@Environment(\.accessibilityReduceMotion)` plumbing to the accessibility step and **skip the cosmetic 600 ms beat** under Reduce Motion. Deliberately did **not** add a step‑transition animation — that would *introduce* motion the wizard doesn't have, crossing the "don't change for the sake of change / protect minimalism" line. The verdict was to *respect* Reduce Motion, and gating the beat satisfies it; step navigation stays byte‑identical to the known‑good baseline. **The onboarding schema version is unchanged** (changing it would re‑trigger onboarding for existing users). | principle |

---

## 5. Empty / error / permission‑denied states

| Surface | Eloquent | Murmur today | Verdict | Reasoning | Source |
|---|---|---|---|---|---|
| **Empty: history** | `noTranscriptions` "No transcriptions". | History window: `tray` icon + "No transcripts yet" + "Dictations you make while history is enabled will appear here." Menubar: `(no transcriptions yet)`. | **KEEP** | Murmur's empty state is more guiding. | — |
| **Empty: vocabulary** | n/a (LLM dictionary). | `text.book.closed` + "No vocabulary yet" + "Click + to add a misheard word and its replacement." | **KEEP** | Clear next action present. | — |
| **Error: transcription/insert** | Apologetic + fallback chains. | Notch `.error` + Retry; contextual copied‑only fallback. | **KEEP** | Actionable and quiet. | — |
| **Permission denied (mic / AX)** | "Grant Permissions" → System Settings; runtime AX handling. | Onboarding status pills + System Settings deep‑links; menubar `⚠ Grant Accessibility Permission`. | **KEEP** | Murmur covers both the wizard and the persistent menubar nudge. | — |
| **Download failure** | "Download Failed". | Red `Download failed: <error>` footnote (inline). | **KEEP** | Present and specific. | — |

---

## 6. Microcopy tone

| Aspect | Eloquent | Murmur | Verdict | Reasoning |
|---|---|---|---|---|
| Voice | Friendly Google‑product voice; exclamatory success ("Download Complete!", "Voice Edits applied!"); privacy‑reassuring. | Quiet, warm, specific ("Made with ♥ for people who like their voice to stay on their Mac."; serif‑italic "Trigger / Speak / Land" acts; "Heard you loud and clear."). | **KEEP** | Murmur already has a distinctive, consistent voice. **Do not Google‑ify it** — in particular, do not import exclamatory "Complete!" toasts. |

---

## 7. LLM‑only surfaces — **N/A (not adopted)**

Murmur deliberately has **no** large‑language‑model features and wants none. Every Eloquent surface
below exists only to support its on‑device/cloud LLM (Gemma) and is **explicitly excluded**.

| Eloquent surface | What it is | Verdict | Reasoning | Source |
|---|---|---|---|---|
| **Voice Edit** (`VoiceEditDialog`, `voice_edit_icon.png`) | Speak commands to edit existing text via the LLM. | **N/A — LLM** | Pure LLM editing surface; no deterministic analog. | bundle |
| **Text‑style transforms** (`tabFormal`/`tabShort`/`tabLong`/`tabPolish`/`tabKeyPoints`) | LLM rewrites (formalize, shorten, lengthen, summarize key points). | **N/A — LLM** | Rewriting/summarization is LLM by definition; Murmur's Prompts tab does deterministic cleanup only. | bundle |
| **Text "polishing"** (`onDevicePolisherType`/`serverPolisherType`) | LLM cleanup between raw ASR and inserted text (drives the "cleaning" indicator state). | **N/A — LLM** | Murmur's cleanup is regex/profile‑based and instant — no LLM, no "cleaning" state. | bundle |
| **Cloud / Gemini toggle** (`isCloudEnabled`, "Enhanced text cleanup with Gemini on server") | Opt into server‑side LLM processing. | **N/A — LLM** | Murmur is fully local with no cloud processing toggle by design. | bundle |
| **Gmail‑mined dictionary / learn‑from‑edits** ("Locally processing your recent Gmail data to extract terms") | LLM‑adjacent personalization. | **N/A — LLM** | Out of identity (mailbox mining); Murmur's vocabulary is manual + deterministic. | bundle |
| **Account / Google sign‑in** (`SignInPage`, `GIDClientID`, OAuth URL schemes) | Google account login + import. | **N/A — LLM** (account) | Murmur is account‑free and local; no sign‑in surface. | bundle |
| **Live‑transcript toggle / instant‑transcript** (`liveTranscription`, `instantTranscriptInFloatingPanel`) | Show streaming transcript / skip the LLM polish. | **N/A — LLM** | The "skip polishing" option only makes sense because polishing is an LLM step; Murmur has neither. (Streaming display itself is a deliberate non‑feature — Murmur pastes finished text.) | bundle |
| **Model‑reasoning / "preparing"/"post‑editing" dialogs** (`PreparingDialog`, `PostEditingDialog`, "Extending session capacity…", "Context window limit reached…") | LLM session/context management UI. | **N/A — LLM** | Context windows and session capacity are LLM concerns; deterministic transcription has none. | bundle |

---

## 8. Theming & accessibility (cross‑cutting)

| Aspect | Verdict | Notes |
|---|---|---|
| Light/dark mode | **KEEP** | Murmur uses semantic colors throughout → dark mode works implicitly. The status‑icon ADAPT (§1) must verify the red recording tint in both menu‑bar appearances. |
| Dynamic Type | **KEEP (noted)** | Semantic font styles scale; a few hero icons use fixed `.system(size:)`. Not a regression vs Eloquent; left as‑is to avoid scope creep. |
| Reduce Motion | **Now consistent** | Indicator already honored it (KEEP). Onboarding now honors it too via the §4 ADD — `accessibilityReduceMotion` plumbing that skips the cosmetic auto‑advance beat. No new motion was introduced (the wizard already hard‑cut between steps). |
| VoiceOver labels | **KEEP (noted)** | Onboarding progress dots are labeled; decorative SF Symbols are unlabeled. The status‑icon ADAPT adds an `accessibilityDescription` for the new symbol‑only idle state. |

---

## 9. Implemented changes (the wins only)

Only **ADAPT/ADD** verdicts were implemented. **KEEP** and **N/A‑LLM** surfaces were left untouched.

1. **Menubar declutter** (`main.swift`, ADAPT §1) — moved `Test Setup`, `Open Config`,
   `Open Logs Folder`, and the two disabled status rows (`Raw Transcript Mode`, `Debug Retain
   Audio`) into a new **Diagnostics ▸** submenu. Every action preserved; top‑level menu reduced to
   user‑facing items; the `Trigger: double-tap fn` discoverability hint kept.
2. **Status‑bar symbol** (`main.swift`, ADAPT §1) — replaced the bare `"Murmur"` text with the
   `waveform` SF Symbol (idle), red `mic.fill` (recording), `waveform` (transcribing),
   `arrow.down.circle` (downloading); compact timer/percent text retained; `accessibilityDescription`
   set so VoiceOver still announces "Murmur".
3. **Onboarding Reduce Motion** (`OnboardingWindow.swift`, ADD §4) — onboarding had *no*
   `accessibilityReduceMotion` plumbing. Added it to the accessibility step and now **skip the
   cosmetic 600 ms post‑grant "beat"** under Reduce Motion. No step‑transition animation was
   added (that would introduce motion the wizard doesn't have); the verdict was to *respect*
   Reduce Motion, and skipping the beat does exactly that. Step navigation is byte‑identical to
   the prior baseline. **Onboarding schema version unchanged** (no re‑prompt for existing users).
4. **Model‑download completion notice** (`ModelsTab.swift`, ADAPT §3, minimal) — a single quiet
   `Notifier` notification fires when a Settings‑initiated model download finishes, so a user who
   switched apps learns it's ready. No inline "done" UI added; onboarding's watched download is
   untouched; no state‑machine change.

### Explicitly **not** done
- No live‑transcript display, no "cleaning"/polishing indicator state, no AI‑edit/rewrite/
  summarize/translate/chat surfaces, no cloud toggle, no account/sign‑in, no Gmail mining, no
  Google‑brand styling, no exclamatory "Complete!" toasts — all rejected per the no‑LLM / quiet‑voice
  constraints.
