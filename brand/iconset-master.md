# Iconset master selection

The `.iconset/` and compiled `AppIcon.icns` shipped inside
`Murmur.app/Contents/Resources/` are rendered from:

**`website/apple-touch-icon.svg`** — clean italic serif lowercase `m` +
small red dot on a warm-cream squircle.

## Why not `brand/icon.svg`

The full brand master (`brand/icon.svg`, 1024×1024) is the editorial
poster version: italic serif `m` with a whisper-decay damped sine wave
that fades into the red dot. Beautiful at 512+. Renders test:

| size | brand/icon.svg            | website/apple-touch-icon.svg |
|------|---------------------------|-------------------------------|
| 16px | three downstrokes collapse into a single blurry mass; tail invisible; red dot below threshold | clean italic m, recognisable |
| 32px | letterform smears; tail reads as fuzz; dot still missing | dot visible; m crisp |
| 64px | starts to resolve, dot still subpixel | reads perfectly |
| 1024 | gorgeous full glyph + decay | clean letterform + dot |

App icons are rendered at every size from 16 (Finder list view) to 1024
(About panel / App Store). Per Apple HIG, the same glyph at every size
keeps the brand stable; you do not want the user seeing a different
shape in the Dock vs. the column view.

`apple-touch-icon.svg` reads at every size from 16 to 1024 and preserves
the locked brand: italic serif lowercase m + small red dot, warm cream
squircle. So it is the macOS app-icon master.

## Pipeline

`app/Scripts/render_icons.sh` rasterises the master into
`app/Resources/AppIcon.iconset/` and runs `iconutil` to produce
`app/Resources/AppIcon.icns`. `app/Scripts/build_app.sh` copies the
`.icns` into the bundle and sets `CFBundleIconFile = AppIcon` in
`Info.plist`. If the `.icns` is missing at build time, `build_app.sh`
regenerates it by invoking `render_icons.sh`.

## Re-rendering

Run after any change to `website/apple-touch-icon.svg`:

```
bash app/Scripts/render_icons.sh
```

Requires `rsvg-convert` (`brew install librsvg`) and `iconutil` (macOS).
