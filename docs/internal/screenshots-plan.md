# Screenshots capture plan

Total budget: 12. Every shot has to earn its place. Capture on a 14" or 16" MacBook with a notched display, light mode by default (dark variants where called out), wallpaper set to **macOS Sequoia default** to ground the visual style. Hide menubar clutter via Bartender / set Murmur's menubar icon as the only visible one. Window chrome: stock macOS, no third-party themes.

Resolution rule: capture at 2x (Retina) and export at the listed pixel dimensions. PNG for static, GIF for motion (Gifski, 30 fps, ≤8 MB).

## The 12

### 1. `docs/assets/demo.gif`
- **What:** 6–8 second loop. Cursor in Mail compose, double-tap `fn`, notch overlay flashes red, voice-over caption *"Send the design review notes to Maria by Friday."*, overlay fades, cleaned text pastes into the field.
- **Dimensions:** 1600×900 @ 2x, 30 fps, ≤8 MB after Gifski compression.
- **Annotations:** none — let motion do the work.
- **Used in:** README hero, docs/index.md hero (replaces current placeholder), landing page above-the-fold.

### 2. `docs/assets/hero.png`
- **What:** Static fallback for the GIF. Final frame of the demo (Mail compose with transcript pasted), notch overlay still visible mid-fade.
- **Dimensions:** 2560×1440 @ 2x. Light variant + dark variant (`hero-dark.png`).
- **Annotations:** none.
- **Used in:** README (fallback for GIF-blocked viewers), social card meta tag, MkDocs hero.

### 3. `docs/assets/notch-overlay-recording.png`
- **What:** Close crop of the notch area mid-recording. Red dot pulsing, waveform visible, level meter showing real input.
- **Dimensions:** 1200×280 @ 2x, tight crop on the notch.
- **Annotations:** subtle callout pointing at the waveform: *"Level meter — real-time audio capture."*
- **Used in:** docs/first-run page, README "How it works" section anchor.

### 4. `docs/assets/menubar-icon.png`
- **What:** Top of screen, menubar visible, Murmur's mic icon highlighted (hover state). Click target visible.
- **Dimensions:** 1400×120 @ 2x, cropped to menubar strip.
- **Annotations:** one arrow pointing at the icon, label *"Murmur"*.
- **Used in:** docs/first-run, docs/permissions.

### 5. `docs/assets/settings-general.png`
- **What:** Settings window, **General** tab selected. Default state, no fields edited.
- **Dimensions:** 1600×1100 @ 2x, full window with shadow.
- **Annotations:** none.
- **Used in:** docs/settings (top of page), README features table link target.

### 6. `docs/assets/settings-models.png`
- **What:** Settings window, **Models** tab. Show `base.en` downloaded (green check), `medium` mid-download with progress bar at ~60%, `large-v3` not downloaded.
- **Dimensions:** 1600×1100 @ 2x.
- **Annotations:** subtle callout on the progress bar: *"SHA-verified download."*
- **Used in:** docs/models, docs/settings, landing page features grid.

### 7. `docs/assets/settings-prompts.png`
- **What:** Settings window, **Prompts** tab. Four profile cards (Raw, Casual, Formal, Code) with Casual selected. Sample input/output pair visible below.
- **Dimensions:** 1600×1100 @ 2x.
- **Annotations:** none.
- **Used in:** docs/prompts, landing page.

### 8. `docs/assets/settings-vocabulary.png`
- **What:** Settings window, **Vocabulary** tab with ~6 example entries (`Murmur`, `whisper.cpp`, `Anthropic`, an internal codename, etc.). Import/Export buttons visible.
- **Dimensions:** 1600×1100 @ 2x.
- **Annotations:** none.
- **Used in:** docs/vocabulary.

### 9. `docs/assets/history-window.png`
- **What:** History window with ~12 example transcripts. Search field populated (`design review`), one row expanded to show full transcript + audio scrubber.
- **Dimensions:** 1700×1100 @ 2x.
- **Annotations:** subtle callout on the **opt-in** toggle in the header: *"Off by default."*
- **Used in:** docs/history, README features table link target, landing page privacy section.

### 10. `docs/assets/first-run-permissions.png`
- **What:** Composite (single image, 2-up). Left: macOS Microphone permission prompt. Right: System Settings → Privacy & Security → Accessibility with Murmur toggled on. Murmur's first-run window visible in the background showing both deep-link buttons.
- **Dimensions:** 2400×1400 @ 2x.
- **Annotations:** two numbered badges (1, 2) showing the order.
- **Used in:** docs/first-run, docs/permissions.

### 11. `docs/assets/onboarding-disable-apple-dictation.png`
- **What:** System Settings → Keyboard → Dictation pane with the toggle in the **off** position.
- **Dimensions:** 1600×1000 @ 2x.
- **Annotations:** one arrow pointing at the toggle, label *"Off — Murmur takes over `fn`+`fn`."*
- **Used in:** docs/first-run step 1, FAQ entry about hotkey collisions.

### 12. `docs/assets/architecture-flow.png`
- **What:** Static export of the Mermaid flow in the README's "How it works" section, styled to match brand palette (red accent, classic white). Fallback for Mermaid-blocked renderers.
- **Dimensions:** 1800×500 @ 2x.
- **Annotations:** none — the diagram is self-labeled.
- **Used in:** docs/architecture (top of page), landing page "How it works" band.

## Capture checklist

Before any shot:

- [ ] Wallpaper reset to Sequoia default.
- [ ] Menubar de-cluttered (Bartender → only show Murmur, clock, battery, Wi-Fi).
- [ ] Notifications silenced (Focus → Do Not Disturb).
- [ ] Demo content seeded — Mail draft to Maria, Notes with sample transcripts, History populated with realistic entries.
- [ ] Screen Recording permission granted to QuickTime / Gifski.
- [ ] Display set to 1600×1000 logical (Displays → Default for display).
- [ ] All shots taken in one session for consistent lighting + chrome.

## Out of scope

Deliberately skipping:

- Stock macOS dialogs that show nothing Murmur-specific (Gatekeeper prompt, generic Save panel).
- Sparkle update sheet — it's the standard Sparkle UI, not worth a slot.
- The Updates settings tab — looks identical to General with one toggle.
- Terminal screenshots of the CLI command — the code block in the README is enough.
