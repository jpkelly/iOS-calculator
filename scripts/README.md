# Icon generation — Calculator

The iOS app icon is generated, not hand-drawn in an asset editor, so it can be
regenerated deterministically and the palette stays in sync with the app.

```
python3 scripts/make_icon.py
```

`scripts/make_icon.py` renders a single 1024×1024 master image and writes it to
`Calculator/Assets.xcassets/AppIcon.appiconset/icon-1024.png`.

## Design

The icon is a miniature of the running app:

- **Background** — deep green-slate (`#181D1C`), the app's `Color.bg`, with a
  faint vertical gradient (slightly lighter at the top) for depth.
- **Display** — a warm off-white (`#F4EDE7`, `Color.warmInk`) result number, the
  visual focus, sitting in the upper third like the app's two-line display.
- **Button grid** — a 3×3 pad that echoes the real key layout:
  - **Operators** (÷ × +) in sage (`#56796D`, `Color.opBg`) with dark ink text.
  - **Numbers / AC** in slate-teal (`#2E5261`, `Color.numBg`) with warm-ink text.
  - **Equals** in lavender (`#B1A7BD`, `Color.topBg`) — the top-row color — so
    the "go" key pops, matching the app's use of lavender for the top row.

The palette is the exact source-of-truth colors from the `Color` extension in
`Calculator/ContentView.swift`; keep them in sync if that palette changes.

## Why one 1024 image

Since iOS 17 a single 1024×1024 PNG satisfies every `AppIcon` slot (the system
downscales it for the smaller home-screen sizes and the App Store icon), so the
appiconset holds only `icon-1024.png`. Xcode's `ASSETCATALOG_COMPILER_APPICON_NAME`
is already set to `AppIcon` in the generated `project.yml`/`project.pbxproj`.
