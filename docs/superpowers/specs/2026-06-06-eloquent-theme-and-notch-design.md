# Design: Appearance toggle (light/dark/auto) + richer notch

**Date:** 2026-06-06
**Status:** Approved-by-proxy (user delegated full autonomy; advisor is the review gate)
**Origin:** Follow-up to `docs/ux-evaluation.md`. The user liked Eloquent's bright/white
look and its expressive indicator, and asked for: (1) a **light/white theme via a
light/dark/auto toggle** (keep dark available), and (2) a **richer notch indicator** —
built now, autonomously.

## Non-negotiable constraints (unchanged)
- **No LLM features / no LLM-style UI.** Nothing here adds AI surfaces.
- Don't touch the transcription engine, the state machine's transcription hot path, or
  paste mechanics.
- Protect Murmur's identity: quiet, deterministic, native macOS. The toggle must default
  to **Auto** so existing users see no forced change.
- Respect the **documented "white spectrum bars" preference** — do **not** recolor the bars.

## Part A — Appearance toggle (primary)

### Behavior
A three-way appearance control: **Auto** (follow the system), **Light**, **Dark**. Applied
process-wide via `NSApp.appearance`, which cascades to every window (Settings, Onboarding,
History — all `NSHostingController`-wrapped SwiftUI) and is picked up by SwiftUI's semantic
colors automatically. Default **Auto** → no behavior change for current users.

### Pieces
1. **`AppearanceMode` enum** (`Sources/Murmur/UI/Theme.swift`, new):
   `enum AppearanceMode: String, Codable, CaseIterable, Identifiable { case auto, light, dark }`
   with `label` (Auto/Light/Dark) and `nsAppearance: NSAppearance?`
   (`auto → nil`, `light → .aqua`, `dark → .darkAqua`) and `apply()` that sets
   `NSApp.appearance`. The enum is `String`-backed so it's Foundation-safe to store in
   `Config`; the AppKit bits live in this file (same module → usable from `Config.swift`
   without `Config` importing AppKit). Also declares `Notification.Name.murmurAppearanceChanged`.
2. **`Config.appearance: AppearanceMode`** default `.auto`. Backward-compatible: add the
   property, a defaulted memberwise-init parameter, a `CodingKey`, `decodeIfPresent ?? .auto`
   in `init(from:)`, and `encode`. Old configs lacking the key decode to `.auto`.
3. **Launch apply** (`main.swift` `applicationDidFinishLaunching`): `config.appearance.apply()`
   early (before windows show). Add an observer for `.murmurAppearanceChanged` that calls
   `mode.apply()` on the main actor for live changes.
4. **Settings → General** (`GeneralTab.swift`): a new **Appearance** section above History
   with a `Picker` bound to a `@State appearance`, loaded on appear from `Config`, persisted on
   change (same load→mutate→save pattern as the history toggle), then posts
   `.murmurAppearanceChanged` so the change is instant and global.

### Why General (not a new tab)
A whole tab for one control is clutter (anti-Murmur). General already owns app-wide prefs.

### The notch under Light mode
The notch pill is physically mated to the black hardware notch (concave top corners). A white
pill below a black notch reads as broken. **Decision: the notch stays dark in all appearance
modes** — it's tied to hardware, not to the app theme. The toggle governs the windowed
surfaces. (This is why the user's "Theme toggle" choice, not "Full white everywhere", is the
right fit.) Documented here so it's a deliberate decision, not an oversight.

## Part B — Richer notch (secondary, conservative)

The notch is already expressive (per-state morphing, mic pulse, success bounce, glow, spectrum
bars, reduce-motion aware). It is intricate AppKit/CALayer code and the user is away, so this is
**enhancement, not a rewrite**, and the signature notch-attached form is preserved (no floating
panel). Two additive, reversible CALayer touches that give the Eloquent-style "premium panel"
feel:

1. **Inner top highlight** — a faint 1px light stroke just inside the pill's top edge, giving a
   glassy, dimensional lip. Subtle (~6–8% white). Static, so no Reduce-Motion concern.
2. **Soft ambient elevation shadow** — a gentle drop shadow beneath the pill so it reads as
   floating/elevated from the menu-bar plane (Eloquent's panels are elevated). Distinct from the
   existing state `glowLayer` (red/green state glow); this is a neutral, always-on elevation.

Both are cosmetic, dark-mode-agnostic, and do not touch geometry, the mask path, state logic,
spectrum-bar colors, or timing. Explicitly **not** doing: floating-panel conversion, live
transcript, bar recolor, larger footprint — all either identity-breaking, out of scope, or
against documented preferences.

**Shipped vs deferred (autonomous-session reality):** Item 1 (rim highlight) **shipped** — it
reuses the mask path verbatim, so it is correct by construction and cannot misalign even though
the notch couldn't be screenshotted (locked screen + the notch only appears mid-dictation).
Item 2 (elevation shadow) is **deferred**: a shadow on a masked layer is unreliable (the mask
clips the very shadow that should extend below the pill), and getting it right needs visual
iteration on an unlocked screen — shipping it blind risked a silently-broken or clipped render.
It should be picked up when the screen is available to eyeball.

## Testing & verification
- **Unit:** `AppearanceModeTests` — `nsAppearance` mapping (auto→nil, light→aqua, dark→darkAqua)
  and round-trip `Config` encode/decode preserving `appearance` + defaulting to `.auto` when the
  key is absent (a real backward-compat guard).
- **Build:** `swift build` clean; full suite green (115 + new).
- **Visual:** launch the packaged app, screenshot Settings in **Light** and **Dark**, confirm the
  picker flips the whole UI live; confirm the notch still renders correctly (dark) in Light mode.
  Screenshots are the primary acceptance evidence for the theme.

## Out of scope / deferred
Hotkey-customization tab and live transcript (the other two options the user did *not* pick).
Full-white notch (identity-breaking). Per-window theme overrides (unneeded).
